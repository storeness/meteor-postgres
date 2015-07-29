SQL.Client = (Collection) ->
  Collection = Collection or Object.create SQL.Client::
  Collection.table = Collection.tableName

  Collection.tableElements = {}
  SQL.Client::clearAll()
  Collection


# Load all the shared SQL methods
_.extend SQL.Client::, SQL.Sql::

SQL.Client::createTable = (tableObj) ->
  alasql.fn.Date = Date
  startString = "CREATE TABLE IF NOT EXISTS #{@table} ("
  item = undefined
  subKey = undefined
  valOperator = undefined
  inputString = ''

  for key of tableObj
    @tableElements[key] = key
    inputString += key + ' '
    inputString += @_DataTypes[tableObj[key][0]]
    if _.isArray(tableObj[key]) and tableObj[key].length > 1
      i = 1
      count = tableObj[key].length
      while i < count
        item = tableObj[key][i]
        if _.isObject item
          subKey = Object.keys item
          inputString += " #{@_TableConstraints[subKey]}#{item[subKey]}"
        else
          inputString += " #{@_TableConstraints[item]}"
        i++
    inputString += ', '

  # check to see if id already provided
  startString += 'id serial primary key,' if inputString.indexOf(' id') is -1

  @inputString = "#{startString}#{inputString} created_at Date);"
  @prevFunc = 'CREATE TABLE'
  # create the table
  alasql @inputString, @dataArray
  @clearAll()
  return

SQL.Client::fetch = (server) ->
  @reactiveData?.depend()

  starter = @updateString or @deleteString or @selectString
  input = if @inputString.length > 0 then @inputString else starter + @joinString + @whereString + @orderString + @limitString + @offsetString + @groupString + @havingString + ';'

  try
    result = alasql(input, @dataArray)
  catch e
    @clearAll()

  if server is 'server'
    input = if @inputString.length > 0 then @inputString else starter + @joinString + @whereString + @orderString + @limitString + @offsetString + @groupString + @havingString + ';'
    Meteor.call "#{@table}_fetch", @_convertQueryForServer(input), @dataArray
  @clearAll()
  result

SQL.Client::save = (client) ->
  starter = @updateString or @deleteString or @selectString
  input = if @inputString.length > 0 then @inputString else starter + @joinString + @whereString + ';'

  try
    result = alasql(input, @dataArray)
  catch e
    @clearAll()

  unless client is 'client'
    input = if @inputString.length > 0 then @inputString else starter + @joinString + @whereString + ';'
    @unvalidated = true
    Meteor.call "#{@table}_save", @_convertQueryForServer(input), @dataArray

  @reactiveData.changed() if @reactiveData
  @clearAll()
  result

SQL.Client::_convertQueryForServer = (input) ->
  counter = 1
  _.map(input.split(''), (character) -> if character is "?" then "$#{counter++}" else character).join('')
