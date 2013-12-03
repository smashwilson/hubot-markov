# Markov storage implementation that uses redis hash keys to store the model.
class RedisStorage

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

module.exports = RedisStorage
