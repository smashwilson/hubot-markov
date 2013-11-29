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

Util = require 'util'

class MarkovModel
  constructor: (@storage, @ply) ->

  transitions: (phrase) ->
    words = (word for word in phrase.split /\s+/ when word.length > 0)
    words.unshift null for i in [1..@ply]
    words.push null for i in [1..@ply]
    for i in [0..words.length - @ply - 1]
      { from: words.slice(i, i + @ply), to: words[i + @ply] }

  learn: (phrase) ->
    for t in this.transitions(phrase)
      ts = @storage[t.from] ?= {}
      ts[t.to] = (ts[t.to] or 0) + 1

module.exports = (robot) ->

  model = new MarkovModel(robot.brain.data, 1)

  # The robot hears ALL. You cannot run.
  robot.hear /.+$/, (msg) ->
    tokens = model.learn msg.match[0]

  robot.respond /markov(\s+(.+))?$/i, (msg) ->
    msg.reply "yup yup: #{msg.match[2]}"
