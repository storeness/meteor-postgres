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

  # inputString used by queries, overrides other strings
  # includes: create table, create relationship, drop table, insert
  Collection.inputString = ''
  Collection.autoSelectData = ''
  Collection.autoSelectInput = ''

  # statement starters
  Collection.selectString = ''
  Collection.updateString = ''
  Collection.deleteString = ''

  # chaining statements
  Collection.joinString = ''
  Collection.whereString = ''

  # caboose statements
  Collection.orderString = ''
  Collection.limitString = ''
  Collection.offsetString = ''
  Collection.groupString = ''
  Collection.havingString = ''
  Collection.dataArray = []

  # error logging
  Collection.prevFunc = ''
  Collection

###*
# Data Types
# @type {{$number: string, $string: string, $json: string, $datetime: string, $float: string, $seq: string, $bool: string}}
# @private
###

SQL.Server::_DataTypes =
  $number: 'integer'
  $string: 'varchar(255)'
  $json: 'json'
  $datetime: 'date'
  $float: 'decimal'
  $seq: 'serial'
  $bool: 'boolean'

###*
# Table Constraints
# @type {{$unique: string, $check: string, $exclude: string, $notnull: string, $default: string, $primary: string}}
# @private
###

SQL.Server::_TableConstraints =
  $unique: 'unique'
  $check: 'check '
  $exclude: 'exclude'
  $notnull: 'not null'
  $default: 'default '
  $primary: 'primary key'

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
# Notes: Deletes cascade
# SQL: DROP TABLE <table>
###

SQL.Server::dropTable = ->
  @inputString = "DROP TABLE IF EXISTS #{@table} CASCADE; DROP FUNCTION IF EXISTS notify_trigger_#{@table}() CASCADE;"
  @prevFunc = 'DROP TABLE'
  @

###*
# SQL: INSERT INTO <table> (<fields>) VALUES (<values>)
# Type: Query
# @param insertObj
###

SQL.Server::insert = (insertObj) ->
  valueString = ') VALUES ('
  keys = Object.keys insertObj
  insertString = "INSERT INTO #{@table} ("
  @dataArray = []

  # iterate through array arguments to populate input string parts
  for i in [0..keys.length-1]
    insertString += "#{keys[i]}, "
    @dataArray.push insertObj[keys[i]]
    valueString += "$#{i+1}, "

  @inputString = "#{insertString.substring(0, insertString.length - 2)}#{valueString.substring(0, valueString.length - 2)});"
  @prevFunc = 'INSERT'
  @

###*
# SQL: UPDATE <table> SET (<fields>) = (<values>)
# Type: Statement Starter
# @param {object} updatesObj
# @param {string} updatesObj Key (Field)
# @param {string} updatesObj Value (Data)
###

SQL.Server::update = (updatesObj) ->
  updateField = '('
  updateValue = '('
  keys = Object.keys updatesObj

  if keys.length > 1
    for i in [0..keys.length-2]
      updateField += "#{keys[i]}, "
      updateValue += "'#{updatesObj[keys[i]]}', "

    updateField += keys[keys.length - 1]
    updateValue += "'#{updatesObj[keys[keys.length - 1]]}'"
  else
    updateField += keys[0]
    updateValue += "'#{updatesObj[keys[0]]}'"

  @updateString = "UPDATE #{@table} SET #{updateField}) = #{updateValue})"
  @prevFunc = 'UPDATE'
  @

###*
# SQL: DELETE FROM table
# Type: Statement Starter
# Notes: If not chained with where it will remove all rows
###

SQL.Server::remove = ->
  @deleteString = "DELETE FROM #{@table}"
  @prevFunc = 'DELETE'
  @

###*
# Parameters: fields (arguments, optional)
# SQL: SELECT fields FROM table, SELECT * FROM table
# Special: May pass table, distinct, field to obtain a single record per unique value
# STATEMENT STARTER/SELECT STRING
#
# SQL: SELECT fields FROM table, SELECT * FROM table
# Type: Statement Starter
# Notes: May pass distinct, field (two separate arguments) to obtain a single record per unique value
# @param {string} [arguments]
# fields to select
###

SQL.Server::select = ->
  args = ''
  if arguments.length >= 1
    for i in [0..arguments.length-1]
      args += 'DISTINCT ' if arguments[i] is 'distinct'
      args += "#{arguments[i]}, " unless arguments[i] is 'distinct'
    args = args.substring(0, args.length - 2)
  else
    args += '*'

  @selectString = "SELECT #{args} FROM #{@table} "
  @prevFunc = 'SELECT'
  @

###*
# SQL: SELECT * FROM table WHERE table.id = id LIMIT 1; SELECT * FROM table LIMIT 1;
# Notes: If no id is passed will return random
# Type: Query
# @param {number} [id]
###

SQL.Server::findOne = ->
  if arguments.length is 1
    @inputString = "SELECT * FROM #{@table} WHERE #{@table}.id = '#{arguments[0]}' LIMIT 1;"
  else
    @inputString = "SELECT * FROM #{@table} LIMIT 1;"

  @prevFunc = 'FIND ONE'
  @

###*
# SQL: JOIN joinTable ON field = field
# Type: Statement
# Notes: Parameters can also be all arrays
# @param {String} joinType
# @param {String} fields
# @param {String} joinTable
###

SQL.Server::join = (joinType, fields, joinTable) ->
  if _.isArray(joinType)
    for i in [0..fields.length-1]
      @joinString = " #{joinType[i]} #{joinTable[i][0]} ON #{@table}.#{fields[i]} = #{joinTable[i][0]}.#{joinTable[i][1]}"
  else
    @joinString = " #{joinType} #{joinTable} ON #{@table}.#{fields} = #{joinTable}.#{joinTable}"

  @prevFunc = 'JOIN'
  @

###*
# SQL: WHERE field operator comparator, WHERE field1 operator1 comparator1 AND/OR field2 operator2 comparator2, WHERE field IN (x, y)
# Type: Statement
# Notes:
# @param {string} directions
# condition with ?'s for values
# @param {string} values
# values to be used
###

SQL.Server::where = ->
  @dataArray = []
  where = ''
  redux = undefined
  substring1 = undefined
  substring2 = undefined
  where += arguments[0]
  for i in [1..arguments.length-1]
    redux = where.indexOf '?'
    substring1 = where.substring 0, redux
    substring2 = where.substring redux + 1, where.length

    if _.isArray(arguments[i])
      throw new Error('Invalid input: array is empty') if arguments[i].length is 0
      where = "#{substring1}ANY($#{i})#{substring2}"
    else
      where = "#{substring1}$#{i}#{substring2}"
    @dataArray.push arguments[i]

  @whereString = " WHERE #{where}"
  @

###*
# SQL: ORDER BY fields
# Notes: ASC is default, add DESC after the field name to reverse
# Type: Caboose
# @param {string} fields
###

SQL.Server::order = ->
  args = ''
  if arguments.length > 1
    for i in [0..arguments.length-1]
      args += "#{arguments[i]}, "
    args = args.substring 0, args.length - 2
  else
    args = arguments[0]

  @orderString = " ORDER BY #{args}"
  @

###*
# SQL: LIMIT number
# Type: Caboose
# @param {number} limit
###

SQL.Server::limit = (limit) ->
  @limitString = " LIMIT #{limit}"
  @

###*
# SQL: OFFSET number
# Type: Caboose
# @param {number} offset
###

SQL.Server::offset = (offset) ->
  @offsetString = " OFFSET #{offset}"
  @

###*
# SQL: GROUP BY field
# Type: Caboose
# @param {string} group
###

SQL.Server::group = (group) ->
  @groupString = "GROUP BY #{group}"
  @


###*
# SQL: SELECT * FROM table ORDER BY table.id ASC LIMIT 1, SELECT * FROM table ORDER BY table.id ASC LIMIT limit
# Type: Query
# @param limit
###

SQL.Server::first = (limit) ->
  limit = limit or 1
  @clearAll()
  @inputString += "SELECT * FROM #{@table} ORDER BY #{@table}.id ASC LIMIT #{limit};"
  @prevFunc = 'FIRST'
  @

###*
# SQL: SELECT * FROM table ORDER BY table.id DESC LIMIT 1, SELECT * FROM table ORDER BY table.id DESC LIMIT limit
# Type: Query
# @param {number} limit
###

SQL.Server::last = (limit) ->
  limit = limit or 1
  @clearAll()
  @inputString += "SELECT * FROM #{@table} ORDER BY #{@table}.id DESC LIMIT #{limit};"
  @prevFunc = 'LAST'
  @

###*
# SQL: SELECT * FROM table LIMIT 1, SELECT * FROM table LIMIT limit
# Type: Query
# @param {number} limit
# Defaults to 1
###

SQL.Server::take = (limit) ->
  limit = limit or 1
  @clearAll()
  @inputString += "SELECT * FROM #{@table} LIMIT #{limit};"
  @prevFunc = 'TAKE'
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
# Type: Maintenance
###

SQL.Server::clearAll = ->
  @inputString = ''
  @autoSelectData = ''
  @autoSelectInput = ''
  # statement starters
  @selectString = ''
  @updateString = ''
  @deleteString = ''
  # chaining statements
  @joinString = ''
  @whereString = ''
  # caboose statements
  @orderString = ''
  @limitString = ''
  @offsetString = ''
  @groupString = ''
  @havingString = ''
  @dataArray = []
  # error logging
  @prevFunc = ''
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
