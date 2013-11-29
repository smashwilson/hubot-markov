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

module.exports = (robot) ->

  # The robot hears ALL. You cannot run.
  robot.hear /./, (msg) ->
    #

  robot.respond /markov( (.*))?/, (msg) ->
    msg.reply 'yup yup'
