describe 'serverSQL', ->

  testTasks = null
  testUsers = null
  fetch = null

  tableTestTasks =
    text: ['$string', '$notnull']

  tableTestUsers =
    username: ['$string', '$notnull']
    age: ['$number']

  serversqlStub = (name) ->
    stub = serverSQL()
    stub.table = name
    stub

  testTasks = serversqlStub 'test_tasks'
  testTasks.dropTable().save()
  testTasks.createTable(tableTestTasks).save()
  _(3).times (n) -> testTasks.insert({ text: "testing#{n + 1}" }).save()
  _(5).times (n) -> testTasks.insert({ text: "testing1" }).save()

  testUsers = serversqlStub 'test_users'
  testUsers.dropTable().save()
  testUsers.createTable(tableTestUsers).save()
  _(3).times (n) ->
    testUsers.insert({ username: "eddie#{n + 1}", age: 2 * n }).save()
    testUsers.insert({ username: "paulo", age: 27 }).save()

  describe 'exceptions', ->

    it 'throws an error if an existing table gets created again', ->
      expect( -> testTasks.createTable(tableTestTasks).save()).toThrow()

    it 'throws an error if an insert contains unknown columns', ->
      expect( -> testTasks.insert({ text: 'failure', username: 'eric' }).save()).toThrow()

    it 'throws an error if an unknown column should get updated', ->
      expect( -> testTasks.update({username: 'kate'}).where('text = ?', 'testing3').save()).toThrow()

    it 'throws no error if an unknown table should get removed', ->
      expect( -> testTasks.dropTable('unknownTable').save()).not.toThrow()

  describe 'fetch', ->

    describe 'findOne', ->

      it 'returns first object without argument', (done) ->
        testTasks.findOne().fetch undefined, undefined, (error, result) ->
          expect(result?.rows).toEqual(jasmine.any(Array))
          expect(result?.rows.length).toBe(1)
          expect(result?.rows[0]).toEqual(jasmine.any(Object))
          expect(result?.rows[0].text).toEqual('testing1')
          done()

      it 'returns object with id as argument', (done) ->
        testTasks.findOne(3).fetch undefined, undefined, (error, result) ->
          console.error(error) if error
          expect(result?.rows).toEqual(jasmine.any(Array))
          expect(result?.rows.length).toBe(1)
          expect(result?.rows[0]).toEqual(jasmine.any(Object))
          expect(result?.rows[0].text).toEqual('testing3')
          done()

    describe 'where', ->

      it 'works with basic where', (done) ->
        testTasks.select().where('text = ?', 'testing1').fetch undefined, undefined, (error, result) ->
          string_where = result?.rows
          expect(string_where.length).toBe(6)
          _.each string_where, (row) -> expect(row.text).toBe('testing1')
          testTasks.select().where('text = ?', ['testing1']).fetch undefined, undefined, (error, result) ->
            array_where = result?.rows
            expect(array_where).toEqual(string_where)
            done()

      it 'works with basic where and limit', (done) ->
        testTasks.select().where('text = ?', 'testing1').limit(3).fetch undefined, undefined, (error, result) ->
          expect(result?.rows.length).toBe(3)
          _.each result?.rows, (row) -> expect(row.text).toBe('testing1')
          done()

      it 'works with basic where and limit and offset', (done) ->
        testTasks.select().where('text = ?', 'testing1').limit(3).offset(2).fetch undefined, undefined, (error, result) ->
          expect(result?.rows.length).toBe(3)
          _.each result?.rows, (row) -> expect(row.text).toBe('testing1')
          done()

      it 'works with basic where and offset', (done) ->
        testTasks.select().where('text = ?', 'testing1').offset(2).fetch undefined, undefined, (error, result) ->
          expect(result?.rows.length).toBe(4)
          _.each result?.rows, (row) -> expect(row.text).toBe('testing1')
          testTasks.select().where('text = ?', 'testing1').offset(6).fetch undefined, undefined, (error, result) ->
            expect(result?.rows.length).toBe(0)
            testTasks.select().where('text = ?', 'testing1').offset(8).fetch undefined, undefined, (error, result) ->
              expect(result?.rows.length).toBe(0)
              done()

      it 'works with array where', (done) ->
        testTasks.select().where('text = ?', ['testing1', 'testing2']).fetch undefined, undefined, (error, result) ->
          expect(result?.rows.length).toBe(7)
          expect(result?.rows[1].text).toBe('testing2')
          done()

      it 'works with multiple placeholder', (done) ->
        testTasks.select().where('id = ? AND text = ?', 2, 'testing2').fetch undefined, undefined, (error, result) ->
          expect(result?.rows.length).toBe(1)
          done()

      it 'works with multiple placeholders and array wheres', (done) ->
        testTasks.select().where('id = ? AND text = ?', [1, 2, 3], ['testing1', 'testing2']).fetch undefined, undefined, (error, result) ->
          expect(result?.rows.length).toBe(2)
          expect(result?.rows[0].id).toBe(1)
          expect(result?.rows[1].id).toBe(2)
          expect(result?.rows[0].text).toBe('testing1')
          expect(result?.rows[1].text).toBe('testing2')
          done()

    describe 'order', ->

      it 'orders correct and ASC by default', (done) ->
        testTasks.select().order('text').fetch undefined, undefined, (error, result) ->
          asc_default = result?.rows
          testTasks.select().order('text ASC').fetch undefined, undefined, (error, result) ->
            asc = result?.rows
            testTasks.select().order('text DESC').fetch undefined, undefined, (error, result) ->
              desc = result?.rows
              expect(asc_default).toEqual(asc)
              expect(asc_default).not.toEqual(desc)
              expect(asc[6]).toEqual(desc[1])

      it 'orders correct on chains', (done) ->
        testTasks.select().where('text = ?', 'testing1').order('id DESC').offset(2).limit(3).fetch undefined, undefined, (error, result) ->
          first = result?.rows
          testTasks.select().where('text = ?', 'testing1').offset(2).order('id DESC').limit(3).fetch undefined, undefined, (error, result) ->
            second = result?.rows
            expect(first).toEqual(second)

    describe 'first', ->

      it 'picks the right `first`', (done) ->
        testTasks.select().offset(2).where('text = ?', 'testing1').order('id DESC').limit(3).first().fetch undefined, undefined, (error, result) ->
          first = result?.rows
          testTasks.select().first(2).fetch undefined, undefined, (error, result) ->
            second = result?.rows
            expect(first[0]).toEqual(second[0])
            done()

    describe 'last', ->

      it 'picks the right `last`', (done) ->
        testTasks.select().last(4).fetch undefined, undefined, (error, result) ->
          first = result?.rows
          expect(first[1].id).toEqual(7)
          testTasks.select().offset(2).where('text = ?', 'testing1').order('id DESC').limit(3).last().fetch undefined, undefined, (error, result) ->
            second = result?.rows
            expect(first[0]).toEqual(second[0])
            done()

    describe 'take', ->

      it 'picks the right with `take`', (done) ->
        testTasks.select().offset(2).order('id DESC').limit(3).take().fetch undefined, undefined, (error, result) ->
          first = result?.rows
          testTasks.select().take().fetch undefined, undefined, (error, result) ->
            second = result?.rows
            expect(first).toEqual(second)
            done()

  describe 'save', ->

    describe 'update', ->

      it 'updates correctly with single argument', (done) ->
        testTasks.select().where('text = ?', 'testing1').fetch undefined, undefined, (error, result) ->
          before = result?.row
          testTasks.update({ text: 'testing1' }).where('text = ?', 'testing2').save undefined, undefined, (error, result) ->
            testTasks.select().where('text = ?', 'testing1').fetch undefined, undefined, (error, result) ->
              after = result?.rows
              expect(before.length + 1).toEqual(after.length)
              done()

      it 'updates correctly with multiple arguments', (done) ->
        testUser.update({username: 'PaulOS', age: 100}).where('username = ?', 'paulo').save undefined, undefined, (error, result) ->
          testUser.select().where('username = ?', 'PaulOS').fetch undefined, undefined, (error, result) ->
            expect(result?.rows.length).toBe(3)
            _.each result?.rows, (item) ->
              expect(item.username).toEqual('PaulOS')
              expect(item.age).toBe(100)
            done()

      it 'updates not when where does not find entries', (done) ->
        testUser.update({username: 'PaulOS', age: 100}).where('username = ?', 'notexist').save undefined, undefined, (error, result) ->
          testUser.select().where('username = ?', 'PaulOS').fetch undefined, undefined, (error, result) ->
            expect(result?.rows.length).toBe(0)
            done()

      it 'updates all', (done) ->
        testTasks.update( {text: 'testing3'} ).save undefined, undefined, (error, result) ->
          testTasks.select().where('text = ?', 'testing1').fetch undefined, undefined, (error, result) ->
            first = result?.row
            testTasks.select().where('text = ?', 'testing3').fetch undefined, undefined, (error, result) ->
              second = result?.row
              expect(first.length).toBe(0)
              expect(second.length).toBe(8)
              done()

    describe 'remove', ->

      it 'removes correctly', (done) ->
        testTasks.where('id = ?', '2').remove().save undefined, undefined, (error, result) ->
          testTasks.select().fetch undefined, undefined, (error, result) ->
            expect(result?.rows.length).toBe(7)
            done()

      it 'removes all', (done) ->
        testTasks.remove().save undefined, undefined, (error, result) ->
          testTasks.select().fetch undefined, undefined, (error, result) ->
            expect(result?.rows.length).toBe(0)
            done()


