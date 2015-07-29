describe 'SQL.Collection', ->

  describe 'initialize', ->

    it 'throws an error if not constructed with `new`', ->
      expect( -> SQL.Collection(null)).toThrow(new Error 'Use new to construct a SQL.Collection')

    it 'throws an error if first argument does not exist', ->
      expect( -> new SQL.Collection()).toThrow(new Error 'First argument to new SQL.Collection must exist')

    it 'throws an error if first argument is not a string', ->
      expect( -> new SQL.Collection(123)).toThrow(new Error 'First argument to new SQL.Collection must be a string or null')
      expect( -> new SQL.Collection([])).toThrow(new Error 'First argument to new SQL.Collection must be a string or null')
      expect( -> new SQL.Collection({})).toThrow(new Error 'First argument to new SQL.Collection must be a string or null')
      expect( -> new SQL.Collection('123')).not.toThrow()
