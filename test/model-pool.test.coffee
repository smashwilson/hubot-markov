{expect} = require 'chai'
ModelPool = require '../src/model-pool'
config = require '../src/config'

describe 'ModelPool', ->
  [c, pool] = []

  beforeEach ->
    c = config {HUBOT_MARKOV_STORAGE: 'memory'}
    pool = new ModelPool(c)

  describe 'with no models', ->
    it 'succeeds on creation', (done) ->
      pool.createModel 'thename', {}, (model) ->
        expect(model.ply).to.equal c.ply
        expect(model.min).to.equal c.learnMin

        done()

    it 'selectively overrides configuration', (done) ->
      expect(c.learnMin).not.to.equal(4)

      pool.createModel 'thename', {learnMin: 4}, (model) ->
        expect(model.ply).to.equal c.ply
        expect(model.min).to.equal 4

        done()

    it 'validates storage kind', ->
      fn = ->
        pool.createModel 'thename', {storage: 'quantum'}
      expect(fn).to.throw /quantum/

    it 'throws on attempt to access a nonexistent model', ->
      fn = ->
        pool.modelNamed 'thename', () ->
      expect(fn).to.throw /Unrecognized/

  describe 'with an existing model', ->
    [existingModel] = []

    beforeEach (done) ->
      pool.createModel 'existing', {}, (model) ->
        existingModel = model
        done()

    it 'allows the creation of differently named models', (done) ->
      pool.createModel 'different', {}, (model) ->
        expect(model.ply).to.equal c.ply
        expect(model.min).to.equal c.learnMin
        expect(model).not.to.equal existingModel

        done()

    it 'prevents the creation of similarly named models', ->
      fn = ->
        pool.createModel 'existing', {}
      expect(fn).to.throw /duplicate/

    it 'prevents the creation of duplicate model names synchronously', ->
      pool.createModel 'another', {}
      fn = ->
        pool.createModel 'another', {}
      expect(fn).to.throw /duplicate/

    it 'permits access to the created model', (done) ->
      pool.modelNamed 'existing', (model) ->
        expect(model).to.equal existingModel
        done()

    it 'permits asynchronous access to models being initialized', (done) ->
      called = false

      pool.createModel 'another', {}
      pool.modelNamed 'another', ->
        called = true
        done()

      expect(called).to.be.false
