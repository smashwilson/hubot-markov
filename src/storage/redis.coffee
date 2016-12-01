Redis = require 'redis'
Url = require 'url'

# Markov storage implementation that uses redis hash keys to store the model.
class RedisStorage

  # Create a storage module connected to Redis.
  # Key prefix is used to isolate stored markov transitions from other keys in the database.
  constructor: (@connStr, @keyPrefix = "markov:") ->
      # Configure redis the same way that redis-brain does.
      info = Url.parse @connStr or
        process.env.REDISTOGO_URL or
        process.env.REDISCLOUD_URL or
        process.env.BOXEN_REDIS_URL or
        process.env.REDIS_URL or
        'redis://localhost:6379'

      @client = Redis.createClient(info.port, info.hostname)

      if info.auth
        @client.auth info.auth.split(":")[1]

  # No initialization necessary for Redis.
  initialize: (callback) ->
    process.nextTick callback

  # Uniformly and unambiguously convert an array of Strings and nulls into a valid
  # Redis key. Uses a length-prefixed encoding.
  #
  # _encode([null, null, "a"]) = "markov:001a"
  # _encode(["a", "bb", "ccc"]) = "markov:1a2b3c"
  _encode: (key) ->
    encoded = for part in key
      if part then "#{part.length}#{part}" else "0"
    @keyPrefix + encoded.join('')

  # Record a transition within the model. "transition.from" is an array of Strings and
  # nulls marking the prior state and "transition.to" is the observed next state, which
  # may be an end-of-chain sentinel.
  increment: (transition, callback) ->
    @client.hincrby(@._encode(transition.from), transition.to, 1)
    callback(null)

  # Retrieve an object containing the possible next hops from a prior state and their
  # relative frequencies. Invokes "callback" with the object.
  get: (prior, callback) ->
    @client.hgetall @._encode(prior), (err, hash) ->
      return callback(err) if err?
      callback(hash)

module.exports = RedisStorage
