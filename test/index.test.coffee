Helper = require 'hubot-test-helper'
helper = new Helper('../src/index.coffee')

async = require 'async'
{expect} = require 'chai'
{sentinel} = require '../src/model'

describe.only 'the catchAll() listener', ->
  [room] = []

  afterEach -> room.destroy() if room?

  describe 'with default settings', ->
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

      room = helper.createRoom()

    it 'silently stores text in the default model', (done) ->
      room.user.say('me', 'aaa bbb ccc')
      .then ->
        expect(room.messages).to.deep.equal [
          ['me', 'aaa bbb ccc']
        ]

        room.robot.markov.modelNamed 'default_forward', (model) ->
          storage = model.storage

          async.parallel [
            (cb) -> storage.get([sentinel], cb) # 0
            (cb) -> storage.get(['aaa'], cb) # 1
            (cb) -> storage.get(['bbb'], cb) # 2
            (cb) -> storage.get(['ccc'], cb) # 3
          ], (err, results) ->
            endMarker = {}
            endMarker[sentinel] = 1

            expect(err).to.not.exist
            expect(results[0]).to.deep.equal({aaa: 1})
            expect(results[1]).to.deep.equal({bbb: 1})
            expect(results[2]).to.deep.equal({ccc: 1})
            expect(results[3]).to.deep.equal(endMarker)

            done()
      false # Don't return a Promise
