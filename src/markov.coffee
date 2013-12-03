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

# TODO: actually read env vars for configuration.
# TODO: use Redis directly for storage instead of robot.brain.
# TODO: docs

Util = require 'util'

class MarkovModel
  sentinel = ' '

  constructor: (@storage, @ply) ->

  _words: (phrase) ->
    (word for word in phrase.split /\s+/ when word.length > 0)

  _random: (max) ->
    Math.floor(Math.random() * (max + 1))

  _chooseWeighted: (choices) ->
    total = 0
    total += freq for key, freq of choices
    chosen = @._random(total)

    acc = 0
    for key, freq of choices
      acc += freq
      return key if acc >= chosen

    throw "Bad choice: #{chosen}"

  _encode: (key) ->
    encoded = for part in key
      if part then "#{part.length}#{part}" else "0"
    encoded.join('')

  _decode: (key) ->
    results = []
    index = 0
    while index < key.length
      length = parseInt key.charAt(index)
      part = key.slice(index + 1, index + 1 + length)
      results.push part
      index += length
    results

  _transitions: (phrase) ->
    words = @._words(phrase)
    words.unshift null for i in [1..@ply]
    words.push null for i in [1..@ply]
    for i in [0..words.length - @ply - 1]
      { from: @._encode(words.slice(i, i + @ply)), to: words[i + @ply] or sentinel }

  learn: (phrase) ->
    for t in @._transitions(phrase)
      ts = @storage[t.from] ?= {}
      ts[t.to] = (ts[t.to] or 0) + 1

  generate: (seed, max) ->
    words = @._words(seed)

    key = words.slice(words.length - @ply, words.length)
    if key.length < @ply
      key.unshift null for i in [1..@ply - key.length]

    chain = []
    chain.push words...

    for i in [words.length..max]
      next = @._chooseWeighted @storage[@._encode(key)]
      break if next is sentinel

      chain.push next
      key.shift()
      key.push next

    chain.join ' '

module.exports = (robot) ->

  robot.brain.data.markov ?= {}
  model = new MarkovModel(robot.brain.data.markov, 2)

  # The robot hears ALL. You cannot run.
  robot.hear /.+$/, (msg) ->
    # Don't learn from commands sent to the bot directly.
    name = robot.name.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&')
    if robot.alias
      alias = robot.alias.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&')
      r = new Regexp("^[@]?(?:#{alias}[:,]?|#{name}[:,]?)")
    else
      r = new Regexp("^[@]?#{name}[:,]?")
    return if r.test msg.match[0]

    model.learn msg.match[0]

  # Generate markov chains on demand, optionally seeded by some initial state.
  robot.respond /markov(\s+(.+))?$/i, (msg) ->
    msg.reply model.generate msg.match[2] or '', 10
