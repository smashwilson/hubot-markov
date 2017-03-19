class AccumulateState

  activate: (@q) ->

  accept: (callback) ->
    @q.callbacks.push(callback)

class ReadyState

  constructor: (@payload) ->

  activate: (@q) ->
    callback(@payload) for callback in @q.callbacks

  accept: (callback) ->
    process.nextTick =>
      callback(@payload)

class NoopState

  activate: (@q) ->

  accept: (callback) ->

# Queue of callbacks to be invoked with a resource that's initialized asynchronously.
#
# When a resource initialization begins, callbacks are accumulated into a queue. Once the resource is available,
# each accumulated callback is invoked with the resource, and any subsequent callbacks are invoked with the
# resource immediately. If the resource's initialization fails, subsequent callbacks are no-ops (the original failure
# should throw or notify).
#
class InitQueue

  constructor: (initState) ->
    @callbacks = []
    @transitionTo(initState)

  transitionTo: (state) ->
    state.activate(this)
    @state = state

  accept: (callback) -> @state.accept(callback)

  ready: (payload) -> @transitionTo(new ReadyState(payload))

  failed: -> @transitionTo(new NoopState())

  @accumulating: -> new InitQueue(new AccumulateState())

module.exports = InitQueue
