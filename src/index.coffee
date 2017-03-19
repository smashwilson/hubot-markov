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
#   HUBOT_MARKOV_STORAGE - Storage engine for model data. One of "memory", "redis",
#      or "postgres". Default: redis.
#   HUBOT_MARKOV_STORAGE_URL - Storage location. Interpretation and requirement determined
#     by HUBOT_MARKOV_STORAGE setting.
#   HUBOT_MARKOV_DEFAULT_MODEL - Generate the default model, which learns word
#     transitions from all text. Default: true.
#   HUBOT_MARKOV_REVERSE_MODEL - Generate the reverse model.  Default: true
#   HUBOT_MARKOV_IGNORE_LIST - Comma-separated list of usernames to ignore from the
#      default and reverse models.
#   HUBOT_MARKOV_RESPOND_CHANCE - The probability, between 0.0 and 1.0, that Hubot will respond
#      un-prompted to a message by using the last word in the message as the seed. Default: 0.
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
storageMap = require './storage'

ModelPool = require './model-pool'
defaultListeners = require './default-listeners'

module.exports = (robot) ->
  conf = config process.env

  robot.markov = new ModelPool(conf)
  defaultListeners(robot, conf)
