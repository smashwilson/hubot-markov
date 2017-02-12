InitQueue = require './init-queue'
storageMap = require './storage'
MarkovModel = require './model'

# An instance of this class is available as `robot.markov` after plugin initialization. Used to create and
# access individual markov models by name.
#
class ModelPool

  constructor: (@config) ->
    @byName = {}
    @defaultStorageImpl = storageMap[@config.storageKind]

  # Create a new markov model. Throw an error if a model with this name already exists.
  #
  # Options:
  #  storage [String] - Storage implementation to use for this model. See config.coffee for
  #    valid choices. Optional; defaults to HUBOT_MARKOV_STORAGE.
  #  storageUrl [String] - Initialization URL passed to the storage implementation. Required
  #    with `storage` unless `storage` is set to "memory".
  #  ply [Number] - Number of prior states used to determine the next state in a transition.
  #    Optional; defaults to HUBOT_MARKOV_PLY.
  #  min [Number] - Minimum number of states required in a chain before its transitions are
  #    learned. Optional; defaults to HUBOT_MARKOV_LEARN_MIN.
  #
  createModel: (name, options) ->
    if @byName[name]?
      throw new Error("Attempt to create duplicate markov model: #{name}")

    queue = InitQueue.accumulating()
    @byName[name] = queue

    ply = options.ply or @config.ply
    min = options.learnMin or @config.learnMin

    if options.storage?
      storageImpl = storageMap[options.storage]
      unless storageImpl?
        throw new Error("Unrecognized markov model storage: #{options.storage}")
    else
      storageImpl = @defaultStorageImpl

    storage = new storageImpl(options.storageUrl, name)
    storage.initialize (err) ->
      if err?
        queue.failed()
        throw err

      model = new MarkovModel(storage, ply, min)
      queue.ready model

    return queue

  # Invoke a callback with a `MarkovModel` when it eventually becomes available.
  #
  # If the model name is unrecognized, an error will be thrown. If the model is still being initialized,
  # the callback will be enqueued and fired later when initialization completes. If the model's initialization
  # has failed, nothing will happen (but the initialization failure stack itself will be in your logs).
  #
  modelNamed: (name, callback) ->
    queue = @byName[name]
    unless queue?
      throw new Error("Unrecognized model name #{name}.")
    queue.accept callback
