SQL.Sql = ->


###*
# Data Types
# @type {{$number: string, $string: string, $json: string, $datetime: string, $float: string, $seq: string, $bool: string}}
# @private
###

SQL.Sql::_DataTypes =
  $number: 'integer'
  $string: 'varchar(255)'
  $json: 'json'
  $datetime: 'date'
  $float: 'decimal'
  $seq: 'serial'
  $bool: 'boolean'
  $timestamp: 'timestamp'

###*
# Table Constraints
# @type {{$unique: string, $check: string, $exclude: string, $notnull: string, $default: string, $primary: string}}
# @private
###

SQL.Sql::_TableConstraints =
  $unique: 'unique'
  $check: 'check '
  $exclude: 'exclude'
  $notnull: 'not null'
  $default: 'default '
  $primary: 'primary key'

###*
# Table Constraints (the ones above are column constraints)
# @type {{$foreign: function}}
# @private
###

SQL.Sql::_Constraints =
  $foreign: (opts) ->
    check opts,
      $key: [String]
      $ref:
        $table: String
        $cols: Match.Optional([String])

    quote = (v) -> "\"#{v.replace('"', '\\"')}\""
    sql = "FOREIGN KEY ("
    sql += _.map(opts.$key, quote).join(', ')
    sql += ") REFERENCES #{quote opts.$ref.$table}"
    if opts.$ref.$cols
      sql += " ("
      sql += _.map(opts.$ref.$cols, quote).join(', ')
      sql += ")"
    sql

###*
# Notes: Deletes cascade
# SQL: DROP TABLE <table>
###

SQL.Sql::dropTable = ->
  @inputString = "DROP TABLE IF EXISTS #{@table} CASCADE; DROP FUNCTION IF EXISTS notify_trigger_#{@table}() CASCADE;"
  @prevFunc = 'DROP TABLE'
  @

###*
# SQL: INSERT INTO <table> (<fields>) VALUES (<values>)
# Type: Query
# @param insertObj
###

SQL.Sql::insert = (insertObj) ->
  valueString = ') VALUES ('
  insertObj.id ||= Random.id(19)

  keys = Object.keys insertObj
  insertString = "INSERT INTO #{@table} ("
  @dataArray = []

  # iterate through array arguments to populate input string parts
  for i in [0..keys.length-1]
    insertString += "#{keys[i]}, "
    @dataArray.push insertObj[keys[i]]
    valueString += "$#{i+1}, " if Meteor.isServer
    valueString += '?, ' if Meteor.isClient

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

SQL.Sql::update = (updatesObj) ->
  updateField = ''
  keys = Object.keys updatesObj

  for i in [0..keys.length-1]
    updateField += "#{keys[i]} = #{if _.isString(updatesObj[keys[i]]) then "'#{updatesObj[keys[i]]}'" else updatesObj[keys[i]] }, "


  @updateString = "UPDATE #{@table} SET #{updateField[0..-3]}"
  @prevFunc = 'UPDATE'
  @

###*
# SQL: DELETE FROM table
# Type: Statement Starter
# Notes: If not chained with where it will remove all rows
###

SQL.Sql::remove = ->
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

SQL.Sql::select = ->
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

SQL.Sql::findOne = ->
  if arguments.length is 1
    @inputString = "SELECT * FROM #{@table} WHERE #{@table}.id = $1 LIMIT 1;" if Meteor.isServer
    @inputString = "SELECT * FROM #{@table} WHERE #{@table}.id = ? LIMIT 1;" if Meteor.isClient
    @dataArray.push arguments[0]
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

SQL.Sql::join = (joinType, fields, joinTable) ->
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

SQL.Sql::where = ->
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
      if Meteor.isServer
        where = "#{substring1}ANY($#{i})#{substring2}"
        @dataArray.push arguments[i]
      if Meteor.isClient
        where = "#{substring1}ANY(#{_.map(arguments[i], (value) -> if _.isNumber(value) then "#{value}, " else "'#{value}', ").join('')[0..-3]})#{substring2}"
    else
      where = "#{substring1}$#{i}#{substring2}" if Meteor.isServer
      where = "#{substring1}?#{substring2}" if Meteor.isClient
      @dataArray.push arguments[i]

  @whereString = " WHERE #{where}"
  @


###*
# SQL: ORDER BY fields
# Notes: ASC is default, add DESC after the field name to reverse
# Type: Caboose
# @param {string} fields
###

SQL.Sql::order = ->
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

SQL.Sql::limit = (limit) ->
  @limitString = " LIMIT #{limit}"
  @


###*
# SQL: OFFSET number
# Type: Caboose
# @param {number} offset
###

SQL.Sql::offset = (offset) ->
  @offsetString = " OFFSET #{offset}"
  @

###*
# SQL: GROUP BY field
# Type: Caboose
# @param {string} group
###

SQL.Sql::group = (group) ->
  @groupString = "GROUP BY #{group}"
  @


###*
# SQL: SELECT * FROM table ORDER BY table.id ASC LIMIT 1, SELECT * FROM table ORDER BY table.id ASC LIMIT limit
# Type: Query
# @param limit
###

SQL.Sql::first = (limit) ->
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

SQL.Sql::last = (limit) ->
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

SQL.Sql::take = (limit) ->
  limit = limit or 1
  @clearAll()
  @inputString += "SELECT * FROM #{@table} LIMIT #{limit};"
  @prevFunc = 'TAKE'
  @

###*
# Type: Maintenance
###

SQL.Sql::clearAll = ->
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
