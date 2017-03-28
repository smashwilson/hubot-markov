Helper = require 'hubot-test-helper'
helper = new Helper('../src/index.coffee')

async = require 'async'
{expect} = require 'chai'
{sentinel} = require '../src/model'

describe 'the catchAll() listener', ->
  [room] = []

  beforeEach ->
    process.env.HUBOT_MARKOV_PLY = ''
    process.env.HUBOT_MARKOV_LEARN_MIN = ''
    process.env.HUBOT_MARKOV_GENERATE_MAX = ''
    process.env.HUBOT_MARKOV_STORAGE = 'memory'
    process.env.HUBOT_MARKOV_STORAGE_URL = ''
    process.env.HUBOT_MARKOV_RESPOND_CHANCE = ''
    process.env.HUBOT_MARKOV_DEFAULT_MODEL = ''
    process.env.HUBOT_MARKOV_REVERSE_MODEL = ''
    process.env.HUBOT_MARKOV_INCLUDE_URLS = ''
    process.env.HUBOT_MARKOV_IGNORE_LIST = ''

  afterEach -> room.destroy() if room?

  getTransitionsFrom = (modelName, transitions) ->
    new Promise (resolve, reject) ->
      room.robot.markov.modelNamed modelName, (model) ->
        storage = model.storage

        fetch = (t, cb) -> storage.get(t, cb)

        async.map transitions, fetch, (err, results) ->
          return reject(err) if err?
          resolve(results)

  setTransitions = (modelName, transitions) ->
    new Promise (resolve, reject) ->
      room.robot.markov.modelNamed modelName, (model) ->
        storage = model.storage

        storage.incrementTransitions transitions, resolve

  testDefaultStorage = ->
    room.user.say('me', 'aaa bbb ccc')
    .then ->
      expect(room.messages).to.deep.equal [
        ['me', 'aaa bbb ccc']
      ]

      getTransitionsFrom 'default_forward', [
        [sentinel]
        ['aaa']
        ['bbb']
        ['ccc']
      ]
    .then (results) ->
      endMarker = {}
      endMarker[sentinel] = 1

      expect(results[0]).to.deep.equal({aaa: 1})
      expect(results[1]).to.deep.equal({bbb: 1})
      expect(results[2]).to.deep.equal({ccc: 1})
      expect(results[3]).to.deep.equal(endMarker)

  testGenerateForward = ->
    setTransitions('default_forward', [
      {from: [sentinel], to: 'aa'}
      {from: ['aa'], to: 'bb'}
      {from: ['bb'], to: 'cc'}
      {from: ['cc'], to: sentinel}
    ])
    .then -> room.user.say('me', '@hubot markov')
    .then ->
      expect(room.messages).to.deep.equal [
        ['me', '@hubot markov']
        ['hubot', 'aa bb cc']
      ]

  testGenerateForwardSeeded = ->
    setTransitions('default_forward', [
      {from: [sentinel], to: 'aa'}
      {from: ['aa'], to: 'bb'}
      {from: ['bb'], to: 'cc'}
      {from: ['cc'], to: sentinel}
    ])
    .then -> room.user.say('me', '@hubot markov dd bb')
    .then ->
      expect(room.messages).to.deep.equal [
        ['me', '@hubot markov dd bb']
        ['hubot', 'dd bb cc']
      ]

  testNoDefaultStorage = ->
    expect ->
      room.robot.markov.modelNamed 'default_forward'
    .to.throw /Unrecognized/

  testNoGenerateForward = ->
    room.user.say('me', '@hubot markov')
    .then ->
      expect(room.messages).to.deep.equal [
        ['me', '@hubot markov']
      ]

  testReverseStorage = ->
    room.user.say('me', 'aaa bbb ccc')
    .then ->
      expect(room.messages).to.deep.equal [
        ['me', 'aaa bbb ccc']
      ]

      getTransitionsFrom 'default_reverse', [
        [sentinel]
        ['ccc']
        ['bbb']
        ['aaa']
      ]
    .then (results) ->
      endMarker = {}
      endMarker[sentinel] = 1

      expect(results[0]).to.deep.equal({ccc: 1})
      expect(results[1]).to.deep.equal({bbb: 1})
      expect(results[2]).to.deep.equal({aaa: 1})
      expect(results[3]).to.deep.equal(endMarker)

  testGenerateReverse = ->
    setTransitions('default_reverse', [
      {from: [sentinel], to: 'dd'}
      {from: ['dd'], to: 'cc'}
      {from: ['cc'], to: 'bb'}
      {from: ['bb'], to: sentinel}
    ])
    .then -> room.user.say('me', '@hubot remarkov')
    .then ->
      expect(room.messages).to.deep.equal [
        ['me', '@hubot remarkov']
        ['hubot', 'bb cc dd']
      ]

  testGenerateReverseSeeded = ->
    setTransitions('default_reverse', [
      {from: [sentinel], to: 'dd'}
      {from: ['dd'], to: 'cc'}
      {from: ['cc'], to: 'bb'}
      {from: ['bb'], to: sentinel}
    ])
    .then -> room.user.say('me', '@hubot remarkov cc zz')
    .then ->
      expect(room.messages).to.deep.equal [
        ['me', '@hubot remarkov cc zz']
        ['hubot', 'bb cc zz']
      ]

  testNoReverseStorage = ->
    expect ->
      room.robot.markov.modelNamed 'default_reverse'
    .to.throw /Unrecognized/

  testNoGenerateReverse = ->
    room.user.say('me', '@hubot remarkov')
    .then ->
      expect(room.messages).to.deep.equal [
        ['me', '@hubot remarkov']
      ]

  testGenerateMiddle = ->
    setTransitions('default_forward', [
      {from: [sentinel], to: 'aaa'}
      {from: ['aaa'], to: 'bb0'}
      {from: ['bb0'], to: 'cc0'}
      {from: ['cc0'], to: sentinel}
    ])
    .then ->
      setTransitions 'default_reverse', [
        {from: [sentinel], to: 'aaa'}
        {from: ['aaa'], to: 'bb1'}
        {from: ['bb1'], to: 'cc1'}
        {from: ['cc1'], to: sentinel}
      ]
    .then -> room.user.say('me', '@hubot mmarkov')
    .then ->
      expect(room.messages).to.deep.equal [
        ['me', '@hubot mmarkov']
        ['hubot', 'cc1 bb1 aaa bb0 cc0']
      ]

  testGenerateMiddleSeeded = ->
    setTransitions('default_forward', [
      {from: [sentinel], to: 'aaa'}
      {from: ['aaa'], to: 'bb0'}
      {from: ['bb0'], to: 'cc0'}
      {from: ['cc0'], to: sentinel}
    ])
    .then ->
      setTransitions 'default_reverse', [
        {from: [sentinel], to: 'aaa'}
        {from: ['aaa'], to: 'bb1'}
        {from: ['bb1'], to: 'cc1'}
        {from: ['cc1'], to: sentinel}
      ]
    .then -> room.user.say('me', '@hubot mmarkov bb1 zzzz bb0')
    .then ->
      expect(room.messages).to.deep.equal [
        ['me', '@hubot mmarkov bb1 zzzz bb0']
        ['hubot', 'cc1 bb1 zzzz bb0 cc0']
      ]

  testNoGenerateMiddle = ->
    room.user.say('me', '@hubot mmarkov')
    .then ->
      expect(room.messages).to.deep.equal [
        ['me', '@hubot mmarkov']
      ]

  describe 'with default settings', ->
    # Default settings: forward and reverse default models enabled
    beforeEach -> room = helper.createRoom()

    it 'silently stores text in the default model', testDefaultStorage
    it 'generates text from the default model', testGenerateForward
    it 'generates seeded text from the default model', testGenerateForwardSeeded
    it 'silently stores text in the reverse model', testReverseStorage
    it 'generates text from the reverse model', testGenerateReverse
    it 'generates seeded text from the reverse model', testGenerateReverseSeeded
    it 'generates text from both models', testGenerateMiddle
    it 'generates seeded text from both models', testGenerateMiddleSeeded

  describe 'with only a forward model', ->
    beforeEach ->
      process.env.HUBOT_MARKOV_DEFAULT_MODEL = 'yes'
      process.env.HUBOT_MARKOV_REVERSE_MODEL = 'no'
      room = helper.createRoom()

    it 'silently stores text in the default model', testDefaultStorage
    it 'generates text from the default model', testGenerateForward
    it 'generates seeded text from the default model', testGenerateForwardSeeded
    it "doesn't store in the reverse model", testNoReverseStorage
    it "doesn't generate from the reverse model", testNoGenerateReverse
    it "doesn't generate from the middle", testNoGenerateMiddle

  describe 'with only a reverse model', ->
    beforeEach ->
      process.env.HUBOT_MARKOV_DEFAULT_MODEL = 'no'
      process.env.HUBOT_MARKOV_REVERSE_MODEL = 'yes'
      room = helper.createRoom()

    it "doesn't generate the default model", testNoDefaultStorage
    it "doesn't generate text from the default model", testNoGenerateForward
    it 'silently stores text in the reverse model', testReverseStorage
    it 'generates text from the reverse model', testGenerateReverse
    it 'generates seeded text from the reverse model', testGenerateReverseSeeded
    it "doesn't generate from the middle", testNoGenerateMiddle

  describe 'with neither model', ->
    beforeEach ->
      process.env.HUBOT_MARKOV_DEFAULT_MODEL = 'no'
      process.env.HUBOT_MARKOV_REVERSE_MODEL = 'no'
      room = helper.createRoom()

    it "doesn't generate the default model", testNoDefaultStorage
    it "doesn't generate text from the default model", testNoGenerateForward
    it "doesn't store in the reverse model", testNoReverseStorage
    it "doesn't generate from the reverse model", testNoGenerateReverse
    it "doesn't generate from the middle", testNoGenerateMiddle
