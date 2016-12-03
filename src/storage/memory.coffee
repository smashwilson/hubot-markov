# Markov storage implementation that uses entirely in-memory storage.
class MemoryStorage

  # Create a storage module.
  constructor: (connStr, modelName) ->
    @transitions = {}

  # No initialization necessary.
  initialize: (callback) ->
    process.nextTick callback

  # Record a series of transitions within the model. "transition.from" is an array of Strings and
  # nulls marking the prior state and "transition.to" is the observed next state, which
  # may be an end-of-chain sentinel.
  incrementTransitions: (transitions, callback) ->
    for transition in transitions
      key = transition.from.join(' ')
      hops = (@transitions[key] ?= {})
      prior = hops[transition.to] or 1
      hops[transition.to] = prior + 1
    process.nextTick callback

  # Retrieve an object containing the possible next hops from a prior state and their
  # relative frequencies. Invokes "callback" with any errors and the object.
  get: (prior, callback) ->
    key = prior.join(' ')
    hash = @transitions[key] or {}
    process.nextTick -> callback(null, hash)

module.exports = MemoryStorage
