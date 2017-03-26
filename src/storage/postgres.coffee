{Pool} = require 'pg'
url = require 'url'

# Markov storage implementation that uses a PostgreSQL table to store the model.
class PostgresStorage

  # Create a storage module that connects to PostgreSQL.
  # The model name is used to determine the table that stores this model.
  constructor: (connStr, @modelName = "markov") ->
    params = url.parse(connStr or process.env.DATABASE_URL)
    auth = params.auth.split ':'

    @pool = new Pool
      user: auth[0]
      password: auth[1]
      host: params.hostname
      port: params.port
      database: params.pathname.split('/')[1]
      ssl: process.env.DATABASE_SSL isnt 'false'

    unless /^[a-zA-Z_]+$/.test @modelName
      throw new Error("Invalid characters in model name: [#{@modelName}] Only a-zA-Z_ are allowed.")

    @constraintName = "#{@modelName}_pkey"

  # Ensure that this model's table exists.
  initialize: (callback) ->
    statement = "CREATE TABLE IF NOT EXISTS #{@modelName}
        (from TEXT, to TEXT, frequency INTEGER,
         CONSTRAINT #{@constraintName} PRIMARY KEY (from, to))"
    @pool.query statement, callback

  # Record a set of transitions within the model. "transition.from" is an array of Strings
  # and nulls marking the prior state and "transition.to" is the observed next state, which
  # may be an end-of-chain sentinel.
  incrementTransitions: (transitions, callback) ->
    placeholders = ("($#{i * 2 - 1}, $#{i * 2}, 1)" for i in [1..transitions.length]).join ', '
    values = []
    for transition in transitions
      values.push transition.from.join ' '
      values.push transition.to

    options =
      text: """
        INSERT INTO #{@modelName} (from, to, frequency) VALUES #{placeholders}
        ON CONFLICT #{@constraintName} UPDATE SET frequency = frequency + 1
        """
      values: values
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

  destroy: (callback) ->
    statement = "DROP TABLE IF EXISTS #{@modelName}"
    @pool.query statement, callback

module.exports = PostgresStorage
