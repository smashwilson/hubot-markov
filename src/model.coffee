processors = require './processors'

# A markov model backed by a configurably storage engine that can both learn and
# generate random text.
class MarkovModel

  # Chain termination marker; chosen because _words will never contain whitespace.
  @sentinel = ' '

  # Build a new model with the provided storage backend and order. A markov model's
  # order is the number of prior states that will be examined to determine the
  # probabilities of the next state.
  constructor: (@storage, @ply, @min) ->
    @processor = processors.words

  # Use a pair of functions to transform input presented to the model in .learn()
  # before it's presented to storage and tokens returned by .generate().
  processWith: (@processor) ->

  # Generate a uniformly distributed random number between 0 and max.
  _random: (max) ->
    Math.random() * max

  # Given an object with possible choices as keys and relative frequencies as values,
  # choose a key with probability proportional to its frequency.
  _chooseWeighted: (choices) ->
    return MarkovModel.sentinel unless choices? and choices.length isnt 0

    # Sum the frequencies of the available choices and choose a value within that
    # range.
    total = 0
    total += parseInt(freq) for key, freq of choices
    chosen = @._random(total)

    # Accumulate frequencies as you iterate through the choices. Select the key that
    # contains the "chunk" including the chosen value.
    acc = 0
    for key, freq of choices
      acc += parseInt(freq)
      return key if chosen <= acc

    # If we get here, "chosen" was greater than total.
    throw new Error("Bad choice: #{chosen} from #{total}")

  # Generate each state transition of order @ply among "words". For example,
  # with @ply 2 and a phrase ["a", "b", "c", "d"], this would generate:
  #
  # { from: [' ', ' '] to: 'a' }
  # { from: [' ', 'a'] to: 'b' }
  # { from: ['a', 'b'], to: 'c' }
  # { from: ['b', 'c'], to: 'd' }
  # { from: ['c', 'd'], to: ' ' }
  # { from: ['d', ' '], to: ' ' }
  _transitions: (states) ->
    states.unshift MarkovModel.sentinel for i in [1..@ply]
    states.push MarkovModel.sentinel for i in [1..@ply]
    for i in [0..states.length - @ply - 1]
      { from: states.slice(i, i + @ply), to: states[i + @ply] or MarkovModel.sentinel }

  # Add a phrase to the model. Increments the frequency of each @ply-order
  # state transition extracted from the phrase. Ignores any phrases containing
  # less than @min words.
  learn: (input, callback) ->
    states = @processor.pre(input)

    # Ignore phrases with fewer than the minimum words.
    if states.length < @min
      return process.nextTick callback

    @storage.incrementTransitions(t for t in @._transitions(states), callback)

  # Generate random text based on the current state of the model and invokes
  # "callback" with it. The generated text will begin with "seed" and contain
  # at most "max" words.
  generate: (seed, max, callback) ->
    states = @processor.pre(seed)

    # Create the initial storage key from "seed", if one is provided.
    key = states.slice(states.length - @ply, states.length)
    if key.length < @ply
      key.unshift MarkovModel.sentinel for i in [1..@ply - key.length]

    # Initialize the response chain with the seed.
    chain = []
    chain.push states...

    @processor.post @._generate_more key, chain, max, callback

  # Recursive companion to "generate". Queries @storage for the choices available
  # from next hops from the current state described by "key", selects a hop
  # weighted by frequencies, and pushes it onto the chain. If the chain is complete,
  # invokes the callback and lets the call stack unwind.
  _generate_more: (key, chain, max, callback) ->
    @storage.get key, (err, choices) =>
      return callback(err) if err?

      next = @._chooseWeighted choices
      if next is MarkovModel.sentinel or max <= 0
        callback(null, chain)
      else
        chain.push next

        key.shift()
        key.push next

        @._generate_more(key, chain, max - 1, callback)

module.exports = MarkovModel
