# API

## `robot.markov`

The object available at `robot.markov` is an instance of [`ModelPool`](../src/model-pool.coffee). It defines the following methods:

### `createModel(name, options, callback)`

Construct a new model. Corresponding backing storage (database tables) will be created if necessary.

Available options include:

* `storage` Backing storage implementation name to use for this model. One of `memory`, `redis`, or `postgres`.
* `storageUrl` Connection URL appropriate to the storage provider.
* `ply` Number of consecutive prior states to use to determine probable next states. The higher this is set, the more accurate to the source material the model becomes, but it requires correspondingly greater storage capacity and training data.
* `min` Minimum number of input states to consider when learning new patterns.

All may be omitted; their corresponding [environment variable settings](../README.md#configuration) will be used if unspecified.

The callback argument will be invoked with an instance of the model once it's been successfully created and connected to its backing store. This is most useful for configuring [custom processors](#processwithprocessor).

Raises an `Error` if:

* `storage` is invalid; or
* a model called `name` already exists.

### `modelNamed(name, callback)`

Access a [`MarkovModel`](#markovmodel) instance with a known `name`. Invoke the provided `callback` with the model as its argument once the model has completed initialization, or on the next tick if the model is already initialized.

Raises an `Error` if no model called `name` exists.

## `MarkovModel`

### `processWith(processor)`

A _processor_ is used to transform raw input objects (usually Strings) into an Array of String states to learn, and to transform generated output state sequences to raw output objects (usually Strings). Processors are used to define what a "state" means to a specific model, or to manipulate or filter presented input in arbitrary ways.

Create a processor by constructing an object with `pre` and `post` keys set to functions that perform the corresponding transformation. For example, this is the default processor, which learns sequences of non-empty words:

```coffee
model.processWith
  pre: (input) -> word for word in input.split /\s+/ when word.length > 0
  post: (output) -> output.join ' '
```

### `learn(input, callback)`

Present an input exemplar to the model. Apply this model's [processor](#processwithprocessor) to convert `input` to an Array of states, learn each transition within the state array, then invoke `callback` with any errors that occurred once all modifications have been persisted.

### `generate(seed, max, callback)`

Generate output based on the current state of the model. Begin with the states derived by applying the [preprocessor](#processwithprocessor) to the `seed` object, then follow transition links within the model with probabilities proportional to the link strengths. Invoke the postprocessor on the generated state sequence and invoke the `callback` with any error that occurred and the resulting object.

### `destroy(callback)`

Destroy any persistent storage associated with this model. Call `callback` with any errors that occurred.
