MemoryStorage = require('./memory')

# Markov storage implementation that uses built-in hubot brain
class HubotBrainStorage extends MemoryStorage
  constructor: (connStr, modelName, robot) ->
    super connStr, modelName
    @brain = robot.brain
    @brainKey = 'markov-transitions-'+modelName
    @brain.on 'loaded', =>
      brainData = @brain.get @brainKey
      @transitions = brainData unless !brainData?

  incrementTransitions: (transitions, callback) ->
    super transitions, () =>
      @brain.set @brainKey, @transitions
      process.nextTick callback

module.exports = HubotBrainStorage
