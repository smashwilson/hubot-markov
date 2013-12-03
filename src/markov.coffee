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

Url = require 'url'
Redis = require 'redis'

# A markov model backed by a configurably storage engine that can both learn and
# generate random text.
class MarkovModel

  # Chain termination marker; chosen because _words will never contain whitespace.
  sentinel = ' '

  # Build a new model with the provided storage backend and order. A markov model's
  # order is the number of prior states that will be examined to determine the
  # probabilities of the next state.
  constructor: (@storage, @ply) ->

  # Split a line of text into whitespace-separated, nonempty words.
  _words: (phrase) ->
    (word for word in phrase.split /\s+/ when word.length > 0)

  # Generate a uniformly distributed random number between 0 and max, inclusive.
  _random: (max) ->
    Math.floor(Math.random() * (max + 1))

  # Given an object with possible choices as keys and relative frequencies as values,
  # choose a key with probability proportional to its frequency.
  _chooseWeighted: (choices) ->
    return sentinel unless choices

    # Sum the frequencies of the available choices and choose a value within that
    # range.
    total = 0
    total += parseInt(freq) for key, freq of choices
    chosen = @._random(total)

    # Accumulate frequencies as you iterate through the choices. Select the key that
    # contains the "chunk" including the chosen value.
    acc = 0
    for key, freq of choices
      acc += parseInt(freq)
      return key if chosen <= acc

    # If we get here, "chosen" was greater than total.
    throw "Bad choice: #{chosen} from #{total}"

  # Generate each state transition of order @ply among the words of "phrase". For
  # example, with @ply 2 and a phrase "a b c d", this would generate:
  #
  # { from: [null, null] to: 'a' }
  # { from: [null, 'a'] to: 'b' }
  # { from: ['a', 'b'], to: 'c' }
  # { from: ['b', 'c'], to: 'd' }
  # { from: ['c', 'd'], to: ' ' }
  _transitions: (phrase) ->
    words = @._words(phrase)
    words.unshift null for i in [1..@ply]
    words.push null for i in [1..@ply]
    for i in [0..words.length - @ply - 1]
      { from: words.slice(i, i + @ply), to: words[i + @ply] or sentinel }

  # Add a phrase to the model. Increments the frequency of each @ply-order
  # state transition extracted from the phrase.
  learn: (phrase) ->
    @storage.increment(t) for t in @._transitions(phrase)

  # Generate random text based on the current state of the model and invokes
  # "callback" with it. The generated text will begin with "seed" and contain
  # at most "max" words.
  generate: (seed, max, callback) ->
    words = @._words(seed)

    # Create the initial storage key from "seed", if one is provided.
    key = words.slice(words.length - @ply, words.length)
    if key.length < @ply
      key.unshift null for i in [1..@ply - key.length]

    # Initialize the response chain with the seed.
    chain = []
    chain.push words...

    @._generate_more key, chain, max, callback

  # Recursive companion to "generate". Queries @storage for the choices available
  # from next hops from the current state described by "key", selects a hop
  # weighted by frequencies, and pushes it onto the chain. If the chain is complete,
  # invokes the callback and lets the call stack unwind.
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

# Markov storage implementation that uses redis hash keys to store the model.
class RedisMarkovStorage

  # Prefix used to isolate stored markov transitions from other keys in the database.
  keyprefix = "markov:"

  # Create a storage module that uses the provided Redis connection.
  constructor: (@client) ->

  # Uniformly and unambiguously convert an array of Strings and nulls into a valid
  # Redis key. Uses a length-prefixed encoding.
  #
  # _encode([null, null, "a"]) = "markov:001a"
  # _encode(["a", "bb", "ccc"]) = "markov:1a2b3c"
  _encode: (key) ->
    encoded = for part in key
      if part then "#{part.length}#{part}" else "0"
    keyprefix + encoded.join('')

  # Record a transition within the model. "transition.from" is an array of Strings and
  # nulls marking the prior state and "transition.to" is the observed next state, which
  # may be an end-of-chain sentinel.
  increment: (transition) ->
    @client.hincrby(@._encode(transition.from), transition.to, 1)

  # Retrieve an object containing the possible next hops from a prior state and their
  # relative frequencies. Invokes "callback" with the object.
  get: (prior, callback) ->
    @client.hgetall @._encode(prior), (err, hash) ->
      throw err if err
      callback(hash)

module.exports = (robot) ->

  # Configure redis the same way that redis-brain does.
  info = Url.parse process.env.REDISTOGO_URL or
    process.env.REDISCLOUD_URL or
    process.env.BOXEN_REDIS_URL or
    'redis://localhost:6379'
  client = Redis.createClient(info.port, info.hostname)
  storage = new RedisMarkovStorage(client)

  # Read markov-specific configuration from the environment.
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
