describe 'SQL.Server', ->

  tableTestTasks =
    text: ['$string', '$notnull']

  tableTestUsers =
    username: ['$string', '$notnull']
    age: ['$number']

  sqlStub = (name) ->
    stub = SQL.Server()
    stub.table = name
    stub

  testTasks = sqlStub 'test_tasks'
  testUsers = sqlStub 'test_users'

  beforeEach (done) ->
    try
      testTasks.dropTable().save()
      testUsers.dropTable().save()
    catch e
    testTasks.createTable(tableTestTasks).save()
    _(3).times (n) -> testTasks.insert({ text: "testing#{n + 1}" }).save()
    _(5).times (n) -> testTasks.insert({ text: "testing1" }).save()


    testUsers.createTable(tableTestUsers).save()
    _(3).times (n) ->
      testUsers.insert({ username: "eddie#{n + 1}", age: 2 * n }).save()
      testUsers.insert({ username: "paulo", age: 27 }).save()
    done()

  describe 'exceptions', ->

    it 'throws an error if an insert contains unknown columns', ->
      expect( -> testTasks.insert({ id: 100, text: 'failure', username: 'eric' }).save()).toThrow()

    it 'throws an error if an unknown column gets updated', ->
      expect( -> testTasks.update({username: 'kate'}).where('text = ?', 'testing3').save()).toThrow()

    it 'throws an error if an existing table gets created again', ->
      expect( -> testTasks.createTable(tableTestTasks).save()).toThrow()

    it 'throws no error if an unknown table gets removed', ->
      expect( -> testTasks.dropTable('unknownTable').save()).not.toThrow()

  describe 'fetch', ->

    describe 'findOne', ->

      it 'returns first object without argument', ->
        result = testTasks.findOne().fetch()?.rows
        expect(result).toEqual(jasmine.any(Array))
        expect(result.length).toBe(1)
        expect(result[0]).toEqual(jasmine.any(Object))
        expect(result[0].text).toEqual('testing1')

      it 'returns object with id as argument', ->
        result = testTasks.findOne(3).fetch()?.rows
        expect(result).toEqual(jasmine.any(Array))
        expect(result.length).toBe(1)
        expect(result[0]).toEqual(jasmine.any(Object))
        expect(result[0].text).toEqual('testing3')

    describe 'where', ->

      it 'works with basic where', ->
        string_where = testTasks.select().where('text = ?', 'testing1').fetch()?.rows
        expect(string_where?.length).toBe(6)
        _.each string_where, (row) -> expect(row?.text).toBe('testing1')

        array_where = testTasks.select().where('text = ?', ['testing1']).fetch()?.rows
        expect(JSON.stringify(array_where)).toEqual(JSON.stringify(string_where))

      it 'works with basic where and limit', ->
        result = testTasks.select().where('text = ?', 'testing1').limit(3).fetch()?.rows
        expect(result.length).toBe(3)
        _.each result, (row) -> expect(row?.text).toBe('testing1')

      it 'works with basic where and limit and offset', ->
        result = testTasks.select().where('text = ?', 'testing1').limit(3).offset(2).fetch()?.rows
        expect(result.length).toBe(3)
        _.each result, (row) -> expect(row?.text).toBe('testing1')

      it 'works with basic where and offset', ->
        result = testTasks.select().where('text = ?', 'testing1').offset(2).fetch()?.rows
        expect(result.length).toBe(4)
        _.each result, (row) -> expect(row?.text).toBe('testing1')

        result = testTasks.select().where('text = ?', 'testing1').offset(6).fetch()?.rows
        expect(result.length).toBe(0)

        result = testTasks.select().where('text = ?', 'testing1').offset(8).fetch()?.rows
        expect(result.length).toBe(0)

      it 'works with array where', ->
        result = testTasks.select().where('text = ?', ['testing1', 'testing2']).fetch()?.rows
        expect(result.length).toBe(7)
        expect(result[1].text).toBe('testing2')

      it 'works with multiple placeholder', ->
        result = testTasks.select().where('id = ? AND text = ?', 2, 'testing2').fetch()?.rows
        expect(result.length).toBe(1)

      it 'works with multiple placeholders and array wheres', ->
        result = testTasks.select().where('id = ? AND text = ?', [1, 2, 3], ['testing1', 'testing2']).fetch()?.rows
        expect(result.length).toBe(2)
        expect(result[0].id).toBe(1)
        expect(result[1].id).toBe(2)
        expect(result[0].text).toBe('testing1')
        expect(result[1].text).toBe('testing2')

    describe 'order', ->

      it 'orders correct and ASC by default', ->
        asc_default = testTasks.select().order('text').fetch()?.rows
        asc = testTasks.select().order('text ASC').fetch()?.rows
        desc = testTasks.select().order('text DESC').fetch()?.rows
        expect(JSON.stringify(asc_default)).toEqual(JSON.stringify(asc))
        expect(JSON.stringify(asc_default)).not.toEqual(JSON.stringify(desc))
        expect(JSON.stringify(asc[6])).toEqual(JSON.stringify(desc[1]))

      it 'orders correct on chains', ->
        first = testTasks.select().where('text = ?', 'testing1').order('id DESC').offset(2).limit(3).fetch()?.rows
        second = testTasks.select().where('text = ?', 'testing1').offset(2).order('id DESC').limit(3).fetch()?.rows
        expect(JSON.stringify(first)).toEqual(JSON.stringify(second))

    describe 'first', ->

      it 'picks the right `first`', ->
        first = testTasks.select().offset(2).where('text = ?', 'testing1').order('id DESC').limit(3).first().fetch()?.rows
        second = testTasks.select().first(2).fetch()?.rows
        expect(JSON.stringify(first[0])).toEqual(JSON.stringify(second[0]))

    describe 'last', ->

      it 'picks the right `last`', ->
        first = testTasks.select().last(4).fetch()?.rows
        expect(first[1].id).toEqual(7)
        second = testTasks.select().offset(2).where('text = ?', 'testing1').order('id DESC').limit(3).last().fetch()?.rows
        expect(JSON.stringify(first[0])).toEqual(JSON.stringify(second[0]))

    describe 'take', ->

      it 'picks the right with `take`', ->
        first = testTasks.select().offset(2).order('id DESC').limit(3).take().fetch()?.rows
        second = testTasks.select().take().fetch()?.rows
        expect(JSON.stringify(first)).toEqual(JSON.stringify(second))

  describe 'save', ->

    it 'makes an synchronous call when no arguments are specified', ->
      result = testTasks.update({ text: 'testing1' }).where('text = ?', 'testing1').save()
      expect(result).toEqual(jasmine.any(Object))
      expect(result.command).toBe('UPDATE')

    it 'makes an asynchronous call when a callback is given', (done) ->
      testTasks.update({ text: 'testing1' }).where('text = ?', 'testing1').save Meteor.bindEnvironment (error, result) ->
        expect(error).toBe(null)
        expect(result).toEqual(jasmine.any(Object))
        expect(result.command).toBe('UPDATE')
        done()

    it 'makes an asynchronous call with input and data when all three arguments are given', (done) ->
      testTasks.save 'UPDATE test_tasks SET (text) = (\'testing1\') WHERE text = $1', ['testing1'], Meteor.bindEnvironment (error, result) ->
        expect(error).toBe(null)
        expect(result).toEqual(jasmine.any(Object))
        expect(result.command).toBe('UPDATE')
        done()

    describe 'update', ->

      it 'updates correctly with single argument', ->
        before = testTasks.select().where('text = ?', 'testing1').fetch()?.rows
        testTasks.update({ text: 'testing1' }).where('text = ?', 'testing2').save()
        after = testTasks.select().where('text = ?', 'testing1').fetch()?.rows
        expect(before.length + 1).toEqual(after.length)

      it 'updates correctly with multiple arguments', ->
        testUsers.update({username: 'PaulOS', age: 100}).where('username = ?', 'paulo').save()
        result = testUsers.select().where('username = ?', 'PaulOS').fetch()?.rows
        expect(result.length).toBe(3)
        _.each result, (item) ->
          expect(item?.username).toEqual('PaulOS')
          expect(item?.age).toBe(100)

      it 'updates not when where does not find entries', ->
        testUsers.update({username: 'PaulOS', age: 100}).where('username = ?', 'notexist').save()
        result = testUsers.select().where('username = ?', 'PaulOS').fetch()?.rows
        expect(result.length).toBe(0)

      it 'updates all', ->
        first = testTasks.select().where('text = ?', 'testing1').fetch()?.rows
        testTasks.update( {text: 'testing3'} ).save()
        second = testTasks.select().where('text = ?', 'testing3').fetch()?.rows
        expect(first.length).toBe(6)
        expect(second.length).toBe(8)

    describe 'remove', ->

      it 'removes correctly', ->
        testTasks.where('id = ?', '2').remove().save()
        result = testTasks.select().fetch()?.rows
        expect(result.length).toBe(7)

      it 'removes all', ->
        testTasks.remove().save()
        result = testTasks.select().fetch()?.rows
        expect(result.length).toBe(0)

  describe 'createRelationship', ->

    it 'creates a correct one-to-many relationship', ->
      testTasks.createRelationship('test_users', '$onetomany').save()
      result = testTasks.select().fetch()
      field = _.find result.fields, (field) -> field.name is 'test_usersid'
      expect(field.name).toBeDefined()
      expect(field.name).toBe('test_usersid')

