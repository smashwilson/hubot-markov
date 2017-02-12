# Description:
#   Build a markov model based on everything that Hubot sees. Construct markov
#   chains based on its accumulated history on demand, to produce plausible-
#   sounding and occasionally hilarious nonsense.
#
#   While this is written to support any order of markov model, extensive
#   experimentation has shown that order 1 produces the most funny. Higher-
#   order models occupy a *lot* more storage space and frequently produce
#   exact quotes.
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_MARKOV_PLY - Order of the markov model to build. Default: 1
#   HUBOT_MARKOV_LEARN_MIN - Minimum number of tokens to use in training. Default: 1
#   HUBOT_MARKOV_GENERATE_MAX - Maximum number of tokens in a generated chain. Default: 50
#   HUBOT_MARKOV_RESPOND_CHANCE - The probability, between 0.0 and 1.0, that Hubot will respond
#      un-prompted to a message by using the last word in the message as the seed. Default: 0.
#   HUBOT_MARKOV_REVERSE - Generate the reverse model.  Default: true
#   HUBOT_MARKOV_IGNORELIST - Comma-separated list of usernames to ignore.
#
# Commands:
#   hubot markov <seed> - Generate a markov chain, optionally seeded with the provided phrase.
#   hubot remarkov <seed> - Generate a reverse markov chain, optionally seeded
#   hubot mmarkov <seed> - Generate two markov chains from the given (optional) seed
#
# Author:
#   smashwilson

async = require 'async'

config = require './config'
MarkovModel = require './model'
preprocessor = require './preprocessor'
storageMap = require './storage'

class ModuleState

  constructor: () ->
    @configure(process.env)

  configure: (hash, callback) ->
    console.trace()
    @settings = config(hash)
    tasks = []

    StorageImpl = storageMap[@settings.storageKind]
    storage = new StorageImpl(@settings.storageUrl, 'markov')
    @model = new MarkovModel(storage, @settings.ply, @settings.learnMin)
    @model.preprocessWith preprocessor.words
    tasks.push (cb) => @model.storage.initialize(cb)

    if @settings.reverse
      restorage = new StorageImpl(@settings.storageUrl, 'remarkov')
      @remodel = new MarkovModel(restorage, @settings.ply, @settings.learnMin)
      @remodel.preprocessWith (input) -> preprocess.reverse(preprocessor.words(input))
      tasks.push (cb) => @remodel.storage.initialize(cb)

    console.log 'models created'
    async.parallel tasks, (err) ->
      console.log 'tasks completed'
      callback(err) if callback?

module.exports = (robot) ->
  robot.markov = new ModuleState()

  # The robot hears ALL. You cannot run.
  robot.catchAll (msg) ->
    state = robot.markov
    settings = state.settings

    # Return on empty messages
    return if !msg.message.text

    # Return if message containers a URL
    return if !settings.includeUrls and msg.message.text.match /https?:\/\//

    # Disregard ignored usernames.
    return if msg.message.user.name in settings.ignoreList

    tasks = []
    tasks.push (cb) -> state.model.learn msg.message.text, cb
    if settings.reverse
      tasks.push (cb) -> state.remodel.learn msg.message.text, cb

    if settings.respondChance > 0 and Math.random() < settings.respondChance
      tasks.push (cb) ->
        words = msg.message.text.match /\w+/g
        randword = Math.floor(Math.random() * words.length)
        seed = words[randword]
        if settings.reverse
          state.model.generate seed, max, (right) ->
            seedAndRest = right.split /\s+/
            seed = seedAndRest.shift()
            rest = seedAndRest.join " "
            state.remodel.generate rephrase(seed), max, (left) ->
              left = rephrase left
              msg.send([left, rest].join " ")
              cb()
        else
          state.model.generate seed or '', max, (text) =>
            res = text.match /\w+/g
            if res.length > 2
              msg.send text
            cb()

    async.parallel tasks

  # Generate markov chains on demand, optionally seeded by some initial state.
  robot.respond /markov(\s+(.+))?$/i, (msg) ->
    state = robot.markov
    state.model.generate msg.match[2] or '', max, (text) =>
      msg.send text

  # Remove http and https links from model database
  robot.respond /markov-removehttpkeys/, (msg) ->
    client.keys "markov:*", (err, keys) ->
      for key in keys

        if String(key).match(/http:\/\//)
          client.del(key)
          console.log(key)
        if String(key).match(/https:\/\//)
          client.del(key)
          console.log(key)
    msg.send "HTTP removed from markov"

  if robot.markov.settings.reverse
    # Generate reverse markov chains on demand, optionally seeded by some end state
    robot.respond /remarkov(\s+(.+))?$/i, (msg) ->
      state = robot.markov
      seed = msg.match[2] or ''
      actualSeed = rephrase seed

      state.remodel.generate actualSeed, max, (text) =>
        msg.send rephrase text

    # Generate markov chains with the seed in the middle
    robot.respond /mmarkov(\s+(.+))?$/i, (msg) ->
      state = robot.markov
      seed = msg.match[2] or ''
      state.model.generate seed, max, (right) ->
        # If no seed was given, the backward seed will be the first word
        # of the forward markov.
        # Also, Javascript split, why you no act like python split?
        seedAndRest = right.split /\s+/
        seed = seedAndRest.shift()
        rest = seedAndRest.join " "
        # Arglebargle async
        remodel.generate rephrase(seed), max, (left) ->
          left = rephrase left
          msg.send([left, rest].join " ")
