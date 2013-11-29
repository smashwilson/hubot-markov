chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'

expect = chai.expect

describe 'markov', ->
  beforeEach ->
    @robot =
      respond: sinon.spy()
      hear: sinon.spy()

    require('../src/markov')(@robot)

  it 'breaks input strings into token chains based on ply'
  it 'adds new token chains to the model'
  it 'increments existing token chains in the model'
  it 'generates new strings incrementally based on the model'
  it 'allows generated strings to be seeded'
