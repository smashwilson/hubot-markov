{Pool} = require 'pg'

# Markov storage implementation that uses a PostgreSQL table to store the model.
class PostgresStorage

  # Create a storage module that connects to PostgreSQL.
  # The model name is used to determine the table that stores this model.
  constructor: (connStr, @modelName = "markov") ->
    @pool = new Pool(connStr or
      process.env.DATABASE_URL)

    unless /^[a-zA-Z_]$/.test @modelName
      throw new Error("Invalid characters in model name: [#{@modelName}] Only a-zA-Z_ are allowed.")

    @constraintName = "#{@modelName}_pkey"

  # Ensure that this model's table exists.
  initialize: (callback) ->
    statement = "CREATE TABLE IF NOT EXISTS #{@modelName}
        (from TEXT, to TEXT, frequency INTEGER,
         CONSTRAINT #{@constraintName} PRIMARY KEY (from, to))"
    @pool.query statement, callback

  # Record a transition within the model. "transition.from" is an array of Strings and
  # nulls marking the prior state and "transition.to" is the observed next state, which
  # may be an end-of-chain sentinel.
  increment: (transition, callback) ->
    options =
      text: """
        INSERT INTO #{@modelName} (from, to, frequency) VALUES ($1, $2, 1)
        ON CONFLICT #{@constraintName} UPDATE SET frequency=#{@modelName}.frequency + 1
        """
      values: [transition.from.join(' '), transition.to]
    @pool.query options, callback

  # Retrieve an object containing the possible next hops from a prior state and their
  # relative frequencies. Invokes "callback" with any errors and the object.
  get: (prior, callback) ->
    options =
      text: "SELECT to, frequency FROM #{@modelName} WHERE from = $1"
      values: [prior.join ' ']
    @pool.query options, (err, result) ->
      return callback(err) if err?

      hash = {}
      for row in result.rows
        hash[row.to] = row.frequency

      callback(null, hash)

module.exports = PostgresStorage
