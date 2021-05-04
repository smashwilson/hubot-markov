# Listeners for the default models, which learn forward and reverse word chains
# from a catchAll block and respond to "hubot markov" and "hubot remarkov".
# If configured to do so, randomly respond to arbitrary messages with a
# markov string generated from a word from that message.

processors = require './processors'

reportErr = (msg, err) ->
  msg.send ":boom:\n```#{err.stack}```"

setupModelResponder = (robot, pattern, markovGeneratorFn) ->
  robot.respond pattern, (msg) ->
    markovGeneratorFn msg.match[2] or '', (err, text) ->
      return reportErr(err) if err?
      msg.send text

getModelGenerationCallback = (robot, config, modelName) ->
  return (seed, callback) ->
    robot.markov.modelNamed modelName, (model) ->
      model.generate seed, config.generateMax, callback

generateDefaultModel = (robot, config) ->
  robot.markov.createModel 'default_forward', {}
  robot.markov.generateForward = getModelGenerationCallback(robot, config, 'default_forward')
  # Generate markov chains on demand, optionally seeded by some initial state.
  setupModelResponder robot, /markov(\s+(.+))?$/i, robot.markov.generateForward

  return 'default_forward'

generateReverseModel = (robot, config) ->
  robot.markov.createModel 'default_reverse', {}, (model) ->
    model.processWith processors.reverseWords

  robot.markov.generateReverse = getModelGenerationCallback(robot, config, 'default_reverse')

  # Generate reverse markov chains on demand, optionally seeded by some end state
  setupModelResponder robot, /remarkov(\s+(.+))?$/i, robot.markov.generateReverse

  return 'default_reverse'

generateMiddleModel = (robot, config) ->
  robot.markov.generateMiddle = (seed, callback) ->
    generateRight = getModelGenerationCallback(robot, config, 'default_forward')

    generateRest = (right, cb) ->
      words = processors.words.pre(right)
      rightSeed = words.shift() or ''

      robot.markov.modelNamed 'default_reverse', (model) ->
        model.generate rightSeed, config.generateMax, (err, left) ->
          return cb(err) if err?
          cb(null, [left, words...].join ' ')

    generateRight (err, right) ->
      return callback(err) if err?
      generateRest right, callback

  # Generate markov chains with the seed in the middle
  setupModelResponder robot, /mmarkov(\s+(.+))?$/i, robot.markov.generateMiddle

  return 'default_middle'

getUserModel = (username, config, robot)->
  userModelName = 'user_' + username

  unless robot.markov.byName[userModelName]
    robot.markov.createModel userModelName, {}
    markovGenerateUser = getModelGenerationCallback(robot, config, userModelName)

    # Generate user markov chains on demand, optionally seeded by some end state
    umarkovUserPattern = "umarkov " + username + "(\s+(.+))?$"
    setupModelResponder robot, RegExp(umarkovUserPattern), markovGenerateUser

  return userModelName

attachRobotListener = (robot, listenMode, listener) ->
  if listenMode == 'hear-all'
    robot.hear /.*/i, listener
  else if listenMode == 'catch-all'
    robot.catchAll listener
  else
    robot.hear RegExp("" + listenMode), listener

module.exports = (robot, config) ->
  activeModelNames = []

  if config.defaultModel
    activeModelNames.push generateDefaultModel(robot, config)

  if config.reverseModel
    activeModelNames.push generateReverseModel(robot, config)

  if config.defaultModel and config.reverseModel
    generateMiddleModel robot, config

  if activeModelNames.length isnt 0 or config.createUserModels?
    attachRobotListener robot, config.learningListenMode, (msg) ->
      # Ignore empty messages
      return if !msg.message.text

      # Return if message containers a URL
      return if !config.includeUrls and msg.message.text.match /https?:\/\//

      # Disregard ignored usernames.
      return if msg.message.user.name in config.ignoreList

      # Disregard any messages that have keywords
      for phrase in config.ignoreMessageList
        return if msg.message.text.indexOf(phrase) isnt -1

      # Pass the message to each active model.
      for name in activeModelNames
        robot.markov.modelNamed name, (model) -> model.learn msg.message.text

      # add per-user models to the list as we see them
      username = msg.envelope.user.name
      if config.createUserModels and username not in config.userModelBlackList
        if config.userModelWhiteList.length is 0 or config.userModelWhiteList[username]
          userModelName = getUserModel username, config, robot
          robot.markov.modelNamed userModelName, (model) -> model.learn msg.message.text

    if config.respondChance > 0
      attachRobotListener robot, config.respondListenMode, (msg) ->
        if Math.random() < config.respondChance
          randomWord = msg.random(processors.words.pre msg.message.text) or ''

          if config.reverseModel
            robot.markov.generateMiddle randomWord, (text) -> msg.send text
          else
            robot.markov.generateForward randomWord, (text) -> msg.send text
