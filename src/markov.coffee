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
#   HUBOT_MARKOV_NOREVERSE - Do not generate the reverse model.  Default: 0
#   HUBOT_MARKOV_IGNORELIST - Comma-separated list of usernames to ignore.
#
# Commands:
#   hubot markov <seed> - Generate a markov chain, optionally seeded with the provided phrase.
#   hubot remarkov <seed> - Generate a reverse markov chain, optionally seeded
#   hubot mmarkov <seed> - Generate two markov chains from the given (optional) seed
#
# Author:
#   smashwilson

Url = require 'url'
Redis = require 'redis'

MarkovModel = require './model'
RedisStorage = require './redis-storage'

rephrase = (phrase) ->
  # Straight from MarkovModel
  words = (word for word in phrase.split /\s+/ when word.length > 0)
  words.reverse().join(" ")

module.exports = (robot) ->

  # Configure redis the same way that redis-brain does.
  info = Url.parse process.env.REDISTOGO_URL or
    process.env.REDISCLOUD_URL or
    process.env.BOXEN_REDIS_URL or
    process.env.REDIS_URL or
    'redis://localhost:6379'
  client = Redis.createClient(info.port, info.hostname)

  if info.auth
    client.auth info.auth.split(":")[1]

  # Read markov-specific configuration from the environment.
  ply = process.env.HUBOT_MARKOV_PLY or 1
  min = process.env.HUBOT_MARKOV_LEARN_MIN or 1
  max = process.env.HUBOT_MARKOV_GENERATE_MAX or 50
  pct = Number(process.env.HUBOT_MARKOV_RESPOND_CHANCE or 0)
  # This logic is somewhat convoluted because it's a pain to
  # default something to true, as 'or true' will override explicit
  # false settings.  Default false is easier.
  reverse_disabled = process.env.HUBOT_MARKOV_NOREVERSE or false
  # Realistically HUBOT_MARKOV_NOREVERSE could be anything and coffeescript
  # will treat it as truthy, so don't set it unless you intend to disable.

  ignoreList = (process.env.HUBOT_MARKOV_IGNORELIST or '').split /\s*,\s*/

  storage = new RedisStorage(client)
  if !reverse_disabled
    restorage = new RedisStorage(client, "remarkov:")
  else
    restorage = null

  model = new MarkovModel(storage, ply, min)
  remodel = new MarkovModel(restorage, ply, min) if restorage

  # The robot hears ALL. You cannot run.
  robot.catchAll (msg) ->

    # Return on empty messages
    return if !msg.message.text
    # Return if message has url
    return if msg.message.text.match /http:\/\//
    return if msg.message.text.match /https:\/\//

    # Disregard ignored usernames.
    return if msg.message.user.name in ignoreList

    model.learn msg.message.text
    remodel.learn rephrase msg.message.text if remodel

    # Chance to randomly respond un-prompted
    if pct > 0 and Math.random() < pct
      words = msg.message.text.match /\w+/g
      console.log(words[0])
      randword = Math.floor(Math.random() * words.length + 1)
      seed = words[randword]
      model.generate seed or '', max, (text) =>
        msg.send text

  # Generate markov chains on demand, optionally seeded by some initial state.
  robot.respond /markov(\s+(.+))?$/i, (msg) ->
    model.generate msg.match[2] or '', max, (text) =>
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

  if restorage
    # Generate reverse markov chains on demand, optionally seeded by some end state
    robot.respond /remarkov(\s+(.+))?$/i, (msg) ->

      seed = msg.match[2] or ''
      actualSeed = rephrase seed

      remodel.generate actualSeed, max, (text) =>
        msg.send rephrase text

    # Generate markov chains with the seed in the middle
    robot.respond /mmarkov(\s+(.+))?$/i, (msg) ->
      seed = msg.match[2] or ''
      model.generate seed, max, (right) ->
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
