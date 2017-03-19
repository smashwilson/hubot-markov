# Listeners for the default models, which learn forward and reverse word chains
# from a catchAll block and respond to "hubot markov" and "hubot remarkov".
# If configured to do so, randomly respond to arbitrary messages with a
# markov string generated from a word from that message.

preprocessor = require './preprocessor'

module.exports = (robot, config) ->
  activeModelNames = []

  if config.defaultModel
    robot.markov.createModel 'default_forward', {}
    activeModelNames.push 'default_forward'

    robot.markov.generateForward = (seed, callback) ->
      robot.markov.modelNamed 'default_forward', (model) ->
        model.generate seed, config.generateMax, callback

    # Generate markov chains on demand, optionally seeded by some initial state.
    robot.respond /markov(\s+(.+))?$/i, (msg) ->
      robot.markov.generateForward msg.match[2] or '', (text) -> msg.send text

  if config.reverseModel
    reverseWords = (input) -> preprocessor.reverse(preprocessor.words(input))

    robot.markov.createModel 'default_reverse', {}, (model) ->
      model.preprocessWith reverseWords

    activeModelNames.push 'default_reverse'

    robot.markov.generateReverse = (seed, callback) ->
      robot.markov.modelNamed 'default_reverse', (model) ->
        model.generate seed, config.generateMax, callback

    # Generate reverse markov chains on demand, optionally seeded by some end state
    robot.respond /remarkov(\s+(.+))?$/i, (msg) ->
      robot.markov.generateReverse msg.match[2] or '', (text) -> msg.send text

  if config.defaultModel and config.reverseModel

    robot.markov.generateMiddle = (seed, callback) ->
      generateRight = (cb) ->
        robot.markov.modelNamed 'default_forward', (model) ->
          model.generate seed, config.generateMax, cb

      generateRest = (right, cb) ->
        words = preprocessor.words(right)
        rightSeed = words.shift() or ''
        rest = words.join ' '

        robot.markov.modelNamed 'default_reverse', (model) ->
          model.generate rightSeed, config.generateMax, (left) ->
            cb([left, rest].join ' ')

      generateRight (right) ->
        generateRest right, callback

    # Generate markov chains with the seed in the middle
    robot.respond /mmarkov(\s+(.+))?$/i, (msg) ->
      robot.markov.generateMiddle msg.match[2] or '', (text) -> msg.send text

  if activeModelNames.length isnt 0

    # The robot hears ALL. You cannot run.
    robot.catchAll (msg) ->
      # Ignore empty messages
      return if !msg.message.text

      # Return if message containers a URL
      return if !config.includeUrls and msg.message.text.match /https?:\/\//

      # Disregard ignored usernames.
      return if msg.message.user.name in settings.ignoreList

      # Pass the message to each active model.
      for name in activeModelNames
        robot.markov.modelNamed name, (model) -> model.learn msg.message.text

    if config.respondChance > 0
      robot.catchAll (msg) ->
        if Math.random() < config.respondChance
          randomWord = msg.random(preprocessor.words(msg.message.text)) or ''

          if config.reverseModel
            robot.markov.generateMiddle randomWord, (text) -> msg.send text
          else
            robot.markov.generateForward randomWord, (text) -> msg.send text
