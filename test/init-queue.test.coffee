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
      q = InitQueue.accumulating()
      q.accept (r) -> calls.push {callback: 1, resource: r}
      q.accept (r) -> calls.push {callback: 2, resource: r}
      q.accept (r) -> calls.push {callback: 3, resource: r}

    it 'fires all accumulated callbacks', ->
      q.ready('the thing')
