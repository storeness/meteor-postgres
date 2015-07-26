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
  startString = 'CREATE TABLE IF NOT EXISTS ' + @table + ' ('
  item = undefined
  subKey = undefined
  valOperator = undefined
  inputString = ''
  for key of tableObj
    @tableElements[key] = key
    inputString += key + ' '
    inputString += @_DataTypes[tableObj[key][0]]
    if Array.isArray(tableObj[key]) and tableObj[key].length > 1
      i = 1
      count = tableObj[key].length
      while i < count
        item = tableObj[key][i]
        if typeof item == 'object'
          subKey = Object.keys(item)
          valOperator = @_TableConstraints[subKey]
          inputString += ' ' + valOperator + item[subKey]
        else
          inputString += ' ' + @_TableConstraints[item]
        i++
    inputString += ', '
  # check to see if id already provided
  if inputString.indexOf('id') == -1
    startString += 'id varchar(255) primary key,'
  @inputString = startString + inputString + ' createdat Date); '
  @prevFunc = 'CREATE TABLE'
  this

SQL.Client::fetch = (server) ->
  @reactiveData?.depend()

  starter = @updateString or @deleteString or @selectString
  input = if @inputString.length > 0 then @inputString else starter + @joinString + @whereString + @orderString + @limitString + @offsetString + @groupString + @havingString + ';'

  try
    result = alasql(input, @dataArray)
  catch e
    @clearAll()

  if server == 'server'
    input = if @inputString.length > 0 then @inputString else starter + @joinString + @whereString + @orderString + @limitString + @offsetString + @groupString + @havingString + ';'
    #Meteor.call @fetchMethod, input, @dataArray
  @clearAll()
  result

SQL.Client::save = (client) ->
  starter = @updateString or @deleteString or @selectString
  input = if @inputString.length > 0 then @inputString else starter + @joinString + @whereString + ';'

  console.log(input, @dataArray) if @prevFunc == 'UPDATE'
  try
    result = alasql(input, @dataArray)
  catch e
    @clearAll()

  if client != 'client'
    input = if @inputString.length > 0 then @inputString else starter + @joinString + @whereString + ';'
    @unvalidated = true
    #Meteor.call @saveMethod, input, @dataArray
  if @prevFunc != 'CREATE TABLE'
    @reactiveData.changed() if @reactiveData
  @clearAll()
  result
