buffer = []

###*
# @summary Namespace for SQL-related items
# @namespace
###

SQL.Collection = (connection) ->
  unless @ instanceof SQL.Collection
    throw new Error 'Use new to construct a SQL.Collection'

  @unvalidated = false
  @reactiveData = new (Tracker.Dependency)
  @tableName = connection
  @table = connection
  @saveMethod = @tableName + '_save'
  @fetchMethod = @tableName + '_fetch'
  @_events = []

  unless @tableName
    throw new Error 'First argument to new SQL.Collection must exist'

  unless _.isNull(@tableName) or _.isString(@tableName)
    throw new Error 'First argument to new SQL.Collection must be a string or null'

  SQL.Client(@) if Meteor.isClient
  SQL.Server(@) if Meteor.isServer

  if Meteor.isClient
    # Added will only be triggered on the initial population of the database client side.
    # Data added to any client while the page is already loaded will trigger a 'changed event'
    @addEventListener 'added', (index, msg, name) ->
      @remove().save 'client'
      @insert(message).save 'client' for message in msg.results
      # Triggering Meteor's reactive data to allow for full stack reactivity
      return

    # Changed will be triggered whenever the server database changed while the client has the page open.
    # This could happen from an addition, an update, or a removal, from that specific client, or another client
    @addEventListener 'changed', (index, msg, name) ->
      if msg.removed
        @remove().where('id = ?', msg.tableId).save 'client'
      else if msg.modified
        @update(msg.results).where('id = ?', msg.results.id).save 'client'
      else
        # The message is a new insertion of a message
        # If the message was submitted by this client then the insert message triggered
        # by the server should be an update rather than an insert
        # We use the unvalidated boolean variabe to keep track of this
        if @unvalidated
          @update(msg.results).where('id = ?', -1).save 'client'
          @unvalidated = false
        else
          # The data was added by another client so just a regular insert
          @insert(msg.results).save 'client'
      return

  # setting up the connection between server and client
  selfConnection = undefined
  subscribeArgs = undefined
  if _.isString connection
    subscribeArgs = Array::slice.call arguments, 0
    name = connection
    connection = Meteor.connection if Meteor.isClient
    connection = DDP.connect Meteor.absoluteUrl() if Meteor.isServer
  else
    # SQL.Collection arguments does not use the first argument (the connection)
    subscribeArgs = Array::slice.call arguments, 1

  subsBefore = _.keys connection._subscriptions
  _.extend @, connection.subscribe.apply(connection, subscribeArgs)
  subsNew = _.difference(_.keys(connection._subscriptions), subsBefore)

  unless subsNew.length is 1
    throw new Error 'Subscription failed!'

  @subscriptionId = subsNew[0]
  buffer.push
    connection: connection
    name: name
    subscriptionId: @subscriptionId
    instance: @

  # If first store for this subscription name, register it!
  if _.filter(buffer, ((sub) ->  sub.name is name and sub.connection is connection)).length is 1
    registerStore connection, name
  return

#The code below is originally from Numtel's meteor-mysql but adapted for the purposes of this project (https://github.com/numtel/meteor-mysql/blob/8d7ce8458892f6b255618d884fcde0ec4d04039b/lib/MysqlSubscription.js)

registerStore = (connection, name) ->
  connection.registerStore name,
    beginUpdate: (batchSize, reset) ->
    update: (msg) ->
      idSplit = msg.id.split(':')
      sub = _.filter(buffer, (sub) -> sub.subscriptionId == idSplit[0] )[0].instance
      if idSplit.length is 1 and msg.msg is 'added' and msg.fields and msg.fields.reset is true
        # This message indicates a reset of a result set
        sub.dispatchEvent 'reset', msg
        sub.splice 0, sub.length
      else
        index = msg.id
        oldRow = undefined
        sub.dispatchEvent 'update', index, msg
        switch msg.msg
          when 'added'
            sub.splice index, 0, msg.fields
            sub.dispatchEvent msg.msg, index, msg.fields, msg.collection
          when 'changed'
            sub.splice index, 0, msg.fields
            sub.dispatchEvent msg.msg, index, msg.fields, msg.collection
      sub.changed()
      return
    endUpdate: ->
    saveOriginals: ->
    retrieveOriginals: ->
  return

# Inherit from Array and Tracker.Dependency
SQL.Collection:: = new Array
_.extend(SQL.Collection::, Tracker.Dependency::)
_.extend(SQL.Collection::, SQL.Client::) if Meteor.isClient
_.extend(SQL.Collection::, SQL.Server::) if Meteor.isServer

SQL.Collection::publish = (collname, pubFunc) ->
  methodObj = {}
  context = @

  methodObj[@saveMethod] = (input, dataArray) ->
    context.save input, dataArray, (error, result) ->
      if error
        console.error error.message, input

  methodObj[@fetchMethod] = (input, dataArray) ->
    context.fetch input, dataArray, (error, result) ->
      if error
        console.error error.message, input

  Meteor.methods methodObj
  Meteor.publish collname, ->
    # For this implementation to work you must call getCursor and provide a callback with the select
    # statement that needs to be reactive. The 'caboose' on the chain of calls must be autoSelect
    # and it must be passed the param 'sub' which is defining in the anon function.
    # This is a limitation of our implementation and will be fixed in later versions
    { _publishCursor: (sub) ->
      pubFunc().autoSelect sub
 }
  return

SQL.Collection::_eventRoot = (eventName) ->
  eventName.split('.')[0]

SQL.Collection::_selectEvents = (eventName, invert) ->
  eventRoot = undefined
  testKey = undefined
  testVal = undefined
  unless eventName instanceof RegExp
    eventRoot = @_eventRoot(eventName)
    if eventName is eventRoot
      testKey = 'root'
      testVal = eventRoot
    else
      testKey = 'name'
      testVal = eventName
  _.filter @_events, (event) ->
    pass = undefined
    if eventName instanceof RegExp
      pass = event.name.match(eventName)
    else
      pass = event[testKey] is testVal
    if invert then !pass else pass

SQL.Collection::addEventListener = (eventName, listener) ->
  unless _.isFunction listener
    throw new Error 'invalid-listener'

  @_events.push
    name: eventName
    root: @_eventRoot eventName
    listener: listener

SQL.Collection::initialValue = (eventName, listener) ->
  Postgres.select @tableName

# @param {string} eventName - Remove events of this name, pass without suffix
#                             to remove all events matching root.

SQL.Collection::removeEventListener = (eventName) ->
  @_events = @_selectEvents eventName, true

SQL.Collection::dispatchEvent = (eventName) ->
  listenerArgs = Array::slice.call arguments, 1
  listeners = @_selectEvents eventName
  # Newest to oldest
  i = listeners.length - 1
  while i >= 0
    # Return false to stop further handling
    if listeners[i].listener.apply(@, listenerArgs) is false
      return false
    i--
  true

SQL.Collection::reactive = ->
  @depend()
  @

