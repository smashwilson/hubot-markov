pgp = require('pg-promise')()
url = require 'url'

adaptPromise = (promise, callback) ->
  success = (payload) -> callback(null, payload)
  failure = (err) -> callback(err)
  promise.then(success, failure)
  null

# Markov storage implementation that uses a PostgreSQL table to store the model.
class PostgresStorage

  # Create a storage module that connects to PostgreSQL.
  # The model name is used to determine the table that stores this model.
  constructor: (connStr, @modelName, robot) ->
    unless /^[a-zA-Z_]+$/.test @modelName
      throw new Error("Invalid characters in model name: [#{@modelName}] Only a-zA-Z_ are allowed.")

    @constraintName = "#{@modelName}_pkey"

    if robot? and robot.getDatabase?
      @db = robot.getDatabase()
    else
      @db = pgp(connStr)

  # Ensure that this model's table exists.
  initialize: (callback) ->
    sql = """
      CREATE TABLE IF NOT EXISTS #{@modelName}
      ("from" TEXT, "to" TEXT, frequency INTEGER,
      CONSTRAINT #{@constraintName} PRIMARY KEY ("from", "to"))
      """
    adaptPromise(@db.none(sql), callback)

  # Record a set of transitions within the model. "transition.from" is an array of Strings
  # and nulls marking the prior state and "transition.to" is the observed next state, which
  # may be an end-of-chain sentinel.
  incrementTransitions: (transitions, callback) ->
    grouped = {}
    placeholders = []
    values = []

    for transition in transitions
      key = transition.from.join(' ') + ' ' + transition.to
      grouped[key] =
        from: transition.from.join(' ')
        to: transition.to
        tally: if grouped[key]? then grouped[key].tally + 1 else 1

    count = 1
    for key, {from, to, tally} of grouped
      placeholders.push "($#{count}, $#{count + 1}, $#{count + 2})"
      count += 3
      values.push from, to, tally

    sql = """
      INSERT INTO #{@modelName} ("from", "to", frequency) VALUES #{placeholders.join ', '}
      ON CONFLICT ON CONSTRAINT #{@constraintName}
      DO UPDATE SET frequency = #{@modelName}.frequency + excluded.frequency
    """
    adaptPromise(@db.none(sql, values), callback)

  # Retrieve an object containing the possible next hops from a prior state and their
  # relative frequencies. Invokes "callback" with any errors and the object.
  get: (prior, callback) ->
    sql = """
      SELECT "to", frequency FROM #{@modelName} WHERE "from" = $1
    """
    values = [prior.join ' ']

    adaptPromise @db.any(sql, values), (err, result) ->
      return callback(err) if err?

      hash = {}
      for row in result
        hash[row.to] = row.frequency

      callback(null, hash)

  destroy: (callback) ->
    sql = "DROP TABLE IF EXISTS #{@modelName}"
    adaptPromise(@db.none(sql), callback)

  disconnect: (callback) ->
    process.nextTick -> callback(null)

module.exports = PostgresStorage
