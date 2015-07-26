pg = Npm.require('pg')
clientHolder = {}

removeListeningConnections = ->
  for key of clientHolder
    clientHolder[key].end()
  return

process.on 'exit', removeListeningConnections

_.each ['SIGINT', 'SIGHUP', 'SIGTERM'], (sig) ->
  process.once sig, ->
    removeListeningConnections()
    process.kill process.pid, sig

###*
# @param Collection
# @constructor
###

SQL.Server = (Collection) ->
  Collection = Collection or Object.create SQL.Server::
  Collection.table = Collection.tableName
  Collection.conString = process.env.MP_POSTGRES or process.env.DATABASE_URL

  SQL.Server::clearAll()
  Collection


# Load all the shared SQL methods
_.extend SQL.Server::, SQL.Sql::

###*
# SQL: CREATE TABLE field data_type constraint
# Notes: Required for all SQL Collections, must use prescribed data types and table constraints
# Type: Query
# @param tableObj
###

SQL.Server::createTable = (tableObj) ->
  startString = "CREATE TABLE \"#{@table}\" ("
  item = undefined
  subKey = undefined
  valOperator = undefined
  inputString = ''

  for key of tableObj
    inputString += "#{key} "
    inputString += @_DataTypes[tableObj[key][0]]
    if _.isArray(tableObj[key]) && tableObj[key].length > 1
      for i in [1..(tableObj[key].length-1)]
        item = tableObj[key][i]
        if _.isObject(item)
          subKey = Object.keys item
          valOperator = @_TableConstraints[subKey]
          inputString += " #{valOperator}#{item[subKey]}"
        else
          inputString += " #{@_TableConstraints[item]}"
    inputString += ', '

  # check to see if id already provided
  startString += 'id serial primary key,' if inputString.indexOf('id') is -1

  @inputString = """
    #{startString}#{inputString} createdat TIMESTAMP default now());

    CREATE OR REPLACE FUNCTION notify_trigger_#{@table}() RETURNS trigger AS $$
    BEGIN
      IF (TG_OP = 'DELETE') THEN
        PERFORM pg_notify('notify_trigger_#{@table}', '[{' || TG_TABLE_NAME || ':"' || OLD.id || '"}, { operation: "' || TG_OP || '"}]');
        RETURN old;
      ELSIF (TG_OP = 'INSERT') THEN
        PERFORM pg_notify('notify_trigger_#{@table}', '[{' || TG_TABLE_NAME || ':"' || NEW.id || '"}, { operation: "' || TG_OP || '"}]');
        RETURN new;
      ELSIF (TG_OP = 'UPDATE') THEN
        PERFORM pg_notify('notify_trigger_#{@table}', '[{' || TG_TABLE_NAME || ':"' || NEW.id || '"}, { operation: "' || TG_OP || '"}]');
        RETURN new;
      END IF;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER watched_table_trigger AFTER INSERT OR DELETE OR UPDATE ON #{@table} FOR EACH ROW EXECUTE PROCEDURE notify_trigger_#{@table}();
  """

  @prevFunc = 'CREATE TABLE'
  @

###*
# Type: Query
# @param {string} relTable
# @param {string} relationship
###

SQL.Server::createRelationship = (relTable, relationship) ->
  if relationship is "$onetomany"
    @inputString = "ALTER TABLE #{@table} ADD #{relTable}id INTEGER references #{relTable}(id) ON DELETE CASCADE;"
  else
    @inputString = """
      CREATE TABLE IF NOT EXISTS #{@table + relTable} (
        #{@table}id integer references #{@table}(id) ON DELETE CASCADE,
        #{relTable}id integer references #{relTable}(id) ON DELETE CASCADE,
        PRIMARY KEY(#{@table}id, #{relTable}id));
    """
  @

###*
# Make a synchronous or asynchronous select on the table.
#
# This makes an synchronous call and returns the result. Otherwise throws and
# error
#   query.fetch()
#
# This makes an asynchronous call and runs the callback after the query has
# executed and returns (error, result)
#   query.fetch(function(error, result) { ... })
#
# This makes an asynchronous call but uses the provided input and data for the
# query
#   query.fetch('SOME QUERY', [data as array], function(error, result) { ... })
#
# Type: Data method
# @param {string} input
# @param {array} data
# @param {function} cb
###

SQL.Server::fetch = ->
  callback = _.last arguments
  input = if arguments.length >= 3 then arguments[0] else undefined
  data = if arguments.length >= 3 then arguments[1] else undefined

  data = @dataArray unless data
  unless input
    starter = @updateString or @deleteString or @selectString
    input = if @inputString.length > 0 then @inputString else starter + @joinString + @whereString + @orderString + @limitString + @offsetString + @groupString + @havingString + ';'

  if arguments.length is 0
    executeQuery = Meteor.wrapAsync(@exec, @)
    result = executeQuery(input, data, callback)
    return result
  else
    @exec input, data, callback
  return

SQL.Server::pg = pg

SQL.Server::exec = (input, data, cb) ->
  pg.connect @conString, (err, client, done) ->
    if err and cb
      cb err, null
    console.log(err) if err

    client.query input, data, (error, results) ->
      done()
      if cb
        cb error, results
  @clearAll()

###*
# Make a synchronous or asynchronous insert/update/delete on the table.
#
# This makes an synchronous call and returns the result. Otherwise throws and
# error
#   query.save()
#
# This makes an asynchronous call and runs the callback after the query has
# executed and returns (error, result)
#   query.save(function(error, result) { ... })
#
# This makes an asynchronous call but uses the provided input and data for the
# query
#   query.save('SOME QUERY', [data as array], function(error, result) { ... })
#
# Type: Data method
# @param {string} input
# @param {array} data
# @param {function} cb
###

SQL.Server::save = ->
  callback = _.last arguments
  input = if arguments.length >= 3 then arguments[0] else undefined
  data = if arguments.length >= 3 then arguments[1] else undefined

  data = @dataArray unless data
  unless input
    starter = @updateString or @deleteString or @selectString
    input = if @inputString.length > 0 then @inputString else starter + @joinString + @whereString + ';'

  if arguments.length is 0
    executeQuery = Meteor.wrapAsync(@exec, @)
    result = executeQuery(input, data, callback)
    return result
  else
    @exec input, data, callback
  return

###*
#
# @param sub
###

SQL.Server::autoSelect = (sub) ->
  # We need a dedicated client to watch for changes on each table. We store these clients in
  # our clientHolder and only create a new one if one does not already exist
  table = @table
  prevFunc = @prevFunc
  newWhere = @whereString
  newSelect = newSelect or @selectString
  newJoin = newJoin or @joinString

  @autoSelectInput = if @autoSelectInput != '' then @autoSelectInput else @selectString + @joinString + newWhere + @orderString + @limitString + ';'

  @autoSelectData = if @autoSelectData != '' then @autoSelectData else @dataArray
  value = @autoSelectInput
  @clearAll()

  loadAutoSelectClient = (name, cb) ->
    # Function to load a new client, store it, and then send it to the function to add the watcher
    client = new pg.Client(process.env.MP_POSTGRES)
    client.connect()
    clientHolder[name] = client
    cb client

  autoSelectHelper = (client1) ->
    # Selecting all from the table
    client1.query value, (error, results) ->
      if error
        console.log error, 'in autoSelect top'
      else
        sub._session.send
          msg: 'added'
          collection: sub._name
          id: sub._subscriptionId
          fields:
            reset: false
            results: results.rows

    # Adding notification triggers
    query = client1.query "LISTEN notify_trigger_#{table}"
    client1.on 'notification', (msg) ->
      returnMsg = eval "(#{msg.payload})"
      k = sub._name
      if returnMsg[1].operation is 'DELETE'
        tableId = returnMsg[0][k]
        sub._session.send
          msg: 'changed'
          collection: sub._name
          id: sub._subscriptionId
          index: tableId
          fields:
            removed: true
            reset: false
            tableId: tableId

      else if returnMsg[1].operation is 'UPDATE'
        selectString = "#{newSelect + newJoin} WHERE #{table}.id = '#{returnMsg[0][table]}'"
        pg.connect process.env.MP_POSTGRES, (err, client, done) ->
          if err
            console.log(err, "in #{prevFunc} #{table}")

          client.query selectString, @autoSelectData, (error, results) ->
            if error
              console.log error, 'in autoSelect update'
            else
              done()
              sub._session.send
                msg: 'changed'
                collection: sub._name
                id: sub._subscriptionId
                index: tableId
                fields:
                  modified: true
                  removed: false
                  reset: false
                  results: results.rows[0]

      else if returnMsg[1].operation is 'INSERT'
        selectString = "#{newSelect + newJoin} WHERE #{table}.id = '#{returnMsg[0][table]}'"
        pg.connect process.env.MP_POSTGRES, (err, client, done) ->
          if err
            console.log(err, "in #{prevFunc} #{table}")

          client.query selectString, @autoSelectData, (error, results) ->
            if error
              console.log error
            else
              done()
              sub._session.send
                msg: 'changed'
                collection: sub._name
                id: sub._subscriptionId
                fields:
                  removed: false
                  reset: false
                  results: results.rows[0]

  # Checking to see if this table already has a dedicated client before adding the listener
  if clientHolder[table]
    autoSelectHelper clientHolder[table]
  else
    loadAutoSelectClient table, autoSelectHelper
  return
