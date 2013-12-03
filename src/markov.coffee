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
#   HUBOT_MARKOV_MAX - Maximum number of tokens in a generated chain. Default: 50
#
# Commands:
#   hubot markov <seed> - Generate a markov chain, optionally seeded with the provided phrase.
#
# Notes:
#   This uses robot.brain to store the full markov model, so make sure it's something
#   scalable enough to handle it!
#
# Author:
#   smashwilson

# TODO: docs

Util = require 'util'
Url = require 'url'
Redis = require 'redis'

class MarkovModel
  sentinel = ' '

  constructor: (@storage, @ply) ->

  _words: (phrase) ->
    (word for word in phrase.split /\s+/ when word.length > 0)

  _random: (max) ->
    Math.floor(Math.random() * (max + 1))

  _chooseWeighted: (choices) ->
    return sentinel unless choices

    total = 0
    total += parseInt(freq) for key, freq of choices
    chosen = @._random(total)

    acc = 0
    for key, freq of choices
      acc += parseInt(freq)
      return key if chosen <= acc

    throw "Bad choice: #{chosen}"

  _transitions: (phrase) ->
    words = @._words(phrase)
    words.unshift null for i in [1..@ply]
    words.push null for i in [1..@ply]
    for i in [0..words.length - @ply - 1]
      { from: words.slice(i, i + @ply), to: words[i + @ply] or sentinel }

  learn: (phrase) ->
    @storage.increment(t) for t in @._transitions(phrase)

  generate: (seed, max, callback) ->
    words = @._words(seed)

    key = words.slice(words.length - @ply, words.length)
    if key.length < @ply
      key.unshift null for i in [1..@ply - key.length]

    chain = []
    chain.push words...

    @._generate_more key, chain, max, callback

  _generate_more: (key, chain, max, callback) ->
    @storage.get key, (choices) =>
      next = @._chooseWeighted choices
      if next is sentinel or max <= 0
        callback(chain.join(' '))
      else
        chain.push next

        key.shift()
        key.push next

        @._generate_more(key, chain, max - 1, callback)


class RedisMarkovStorage

  keyprefix = "markov:"

  constructor: (@client) ->

  _encode: (key) ->
    encoded = for part in key
      if part then "#{part.length}#{part}" else "0"
    keyprefix + encoded.join('')

  increment: (transition) ->
    @client.hincrby(@._encode(transition.from), transition.to, 1)

  get: (prior, callback) ->
    @client.hgetall @._encode(prior), (err, hash) ->
      throw err if err
      callback(hash)

module.exports = (robot) ->

  info = Url.parse process.env.REDISTOGO_URL or
    process.env.REDISCLOUD_URL or
    process.env.BOXEN_REDIS_URL or
    'redis://localhost:6379'
  client = Redis.createClient(info.port, info.hostname)
  storage = new RedisMarkovStorage(client)

  ply = process.env.HUBOT_MARKOV_PLY or 1
  max = process.env.HUBOT_MARKOV_MAX or 50

  model = new MarkovModel(storage, ply)

  # The robot hears ALL. You cannot run.
  robot.hear /.+$/, (msg) ->
    # Don't learn from commands sent to the bot directly.
    name = robot.name.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&')
    if robot.alias
      alias = robot.alias.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&')
      r = new RegExp("^[@]?(?:#{alias}[:,]?|#{name}[:,]?)", "i")
    else
      r = new RegExp("^[@]?#{name}[:,]?", "i")
    return if r.test msg.match[0]

    model.learn msg.match[0]

  # Generate markov chains on demand, optionally seeded by some initial state.
  robot.respond /markov(\s+(.+))?$/i, (msg) ->
    model.generate msg.match[2] or '', max, (text) =>
      msg.reply text
