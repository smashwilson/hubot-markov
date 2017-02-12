Helper = require 'hubot-test-helper'

process.env.HUBOT_MARKOV_STORAGE = 'memory'
helper = new Helper('../src/markov.coffee')

async = require 'async'
{expect} = require 'chai'

describe 'the catchAll() listener', ->
  [room] = []

  beforeEach -> room = helper.createRoom()
  afterEach -> room.destroy()

  describe 'with default settings', ->
    beforeEach (done) -> room.robot.configure {}, done

    it.only 'stores text in the default model', (done) ->
      room.user.say('me', 'aaa bbb ccc')
      .then ->
        expect(room.messages).to.deep.equal [
          'me', 'aaa bbb ccc'
        ]

        storage = room.robot.markov.model.storage

        async.parallel [
          (cb) -> storage.get([SENTINEL], cb) # 0
          (cb) -> storage.get(['aaa'], cb) # 1
          (cb) -> storage.get(['bbb'], cb) # 2
          (cb) -> storage.get(['ccc'], cb) # 3
        ], (err, results) ->
          endMarker = {}
          endMarker[SENTINEL] = 1

          expect(err).to.not.exist
          expect(results[0]).to.deep.equal({aaa: 1})
          expect(results[1]).to.deep.equal({bbb: 1})
          expect(results[2]).to.deep.equal({ccc: 1})
          expect(results[3]).to.deep.equal(endMarker)
