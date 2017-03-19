{expect} = require 'chai'
InitQueue = require '../src/init-queue'

describe 'InitQueue', ->
  describe 'while accumulating', ->
    it 'accepts callbacks, but does not invoke them', ->
      calls = []
      q = InitQueue.accumulating()
      q.accept (r) -> calls.push 1
      q.accept (r) -> calls.push 2
      expect(calls).to.deep.equal([])

  describe 'when ready', ->
    [q, calls] = []

    beforeEach ->
      calls = []

      q = InitQueue.accumulating()
      q.accept (r) -> calls.push {callback: 1, resource: r}
      q.accept (r) -> calls.push {callback: 2, resource: r}
      q.accept (r) -> calls.push {callback: 3, resource: r}

    it 'fires all accumulated callbacks asynchronously', (done) ->
      q.ready('the thing')

      q.accept ->
        expect(calls).to.deep.equal [
          {callback: 1, resource: 'the thing'}
          {callback: 2, resource: 'the thing'}
          {callback: 3, resource: 'the thing'}
        ]
        done()

    it 'fires new callbacks on the next tick', (done) ->
      q.ready('a thing')

      q.accept (r) ->
        expect(r).to.equal 'a thing'
        done()

    describe 'when failed', ->
      [q, prevCall] = []

      beforeEach ->
        q = InitQueue.accumulating()
        q.accept (r) -> prevCall = r

      it 'ignores existing callbacks', ->
        q.failed()
        expect(prevCall).to.be.undefined

      it 'ignores new callbacks', ->
        q.failed()

        called = null
        q.accept (r) -> called = r
        expect(called).to.be.null
