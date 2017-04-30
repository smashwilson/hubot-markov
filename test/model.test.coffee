{expect} = require 'chai'
async = require 'async'

MarkovModel = require '../src/model'
storage = require '../src/storage'
processors = require '../src/processors'

SENTINEL = MarkovModel.sentinel
MEMORYTEST_STORAGE = ['memory', 'redis', 'postgres']
if process.env.MEMORYTEST_STORAGE?
  MEMORYTEST_STORAGE = process.env.MEMORYTEST_STORAGE.split(/\s+/).map (klass) -> klass.toLowerCase()

sharedConnection = null

describe 'MarkovModel', ->

  storageClasses = []

  if 'memory' in MEMORYTEST_STORAGE
    storageClasses.push
      name: 'Memory'
      constructor: storage.memory
      connStr: ''
  else
    it 'should be tested with memory storage'

  if 'redis' in MEMORYTEST_STORAGE
    if process.env.REDIS_URL?
      storageClasses.push
        name: 'Redis'
        constructor: storage.redis
        connStr: process.env.REDIS_URL
    else
      it 'is missing ${REDIS_URL} in the test environment', ->
        expect.fail 'missing environment variable'
  else
    it 'should be tested with a redis URL as ${REDIS_URL}'

  if 'postgres' in MEMORYTEST_STORAGE
    if process.env.DATABASE_URL?
      storageClasses.push
        name: 'Postgres'
        constructor: storage.postgres
        connStr: process.env.DATABASE_URL
    else
      it 'is missing ${DATABASE_URL} in the test environment', ->
        expect.fail 'missing environment variable'
  else
    it 'should be tested with a Postgres database at ${DATABASE_URL}'

  it 'should exercise at least one storage implementation', ->
    expect(storageClasses).to.not.be.empty

  generate = (storageClass) ->
    describe "with #{storageClass.name} storage", ->
      [storage, model] = []

      beforeEach (done) ->
        if sharedConnection?
          robot =
            getDatabase: -> sharedConnection

        storage = new storageClass.constructor(storageClass.connStr, 'modelname', robot)
        sharedConnection = storage.db if storage.db?

        storage.initialize ->
          model = new MarkovModel(storage, 2, 3)
          model.processWith processors.identity
          done()

      afterEach (done) ->
        @timeout(5000)
        model.destroy done

      describe '_chooseWeighted()', ->
        it 'returns the sentinel value if there are no choices', ->
          choice = model._chooseWeighted []
          expect(choice).to.equal(SENTINEL)

        it 'chooses a key with the corresponding frequency', ->
          options =
            aaa: 1
            bbb: 2
            ccc: 3

          ITERATION_COUNT = 10000

          occurrences =
            aaa: 0
            bbb: 0
            ccc: 0

          for iteration in [0...ITERATION_COUNT]
            choice = model._chooseWeighted options
            occurrences[choice]++

          expect(occurrences.aaa).to.be.closeTo(ITERATION_COUNT / 6, 500)
          expect(occurrences.bbb).to.be.closeTo(ITERATION_COUNT / 3, 500)
          expect(occurrences.ccc).to.be.closeTo(ITERATION_COUNT / 2, 500)

      describe '_transitions()', ->
        it 'generates each state transition of order @ply among list elements', ->
          ts = model._transitions ['aaa', 'bbb', 'ccc']
          expect(ts).to.deep.equal [
            { from: [SENTINEL, SENTINEL], to: 'aaa' }
            { from: [SENTINEL, 'aaa'], to: 'bbb' }
            { from: ['aaa', 'bbb'], to: 'ccc' }
            { from: ['bbb', 'ccc'], to: SENTINEL }
            { from: ['ccc', SENTINEL], to: SENTINEL }
          ]

        it 'handles lists of less than length @ply', ->
          ts = model._transitions ['aaa']
          expect(ts).to.deep.equal [
            { from: [SENTINEL, SENTINEL], to: 'aaa' }
            { from: [SENTINEL, 'aaa'], to: SENTINEL }
            { from: ['aaa', SENTINEL], to: SENTINEL }
          ]

        it 'handles a higher value of @ply', ->
          model.ply = 4
          ts = model._transitions ['aaa', 'bbb', 'ccc', 'ddd', 'eee', 'fff', 'ggg', 'hhh', 'iii']
          expect(ts).to.deep.equal [
            { from: [SENTINEL, SENTINEL, SENTINEL, SENTINEL], to: 'aaa' }
            { from: [SENTINEL, SENTINEL, SENTINEL, 'aaa'], to: 'bbb' }
            { from: [SENTINEL, SENTINEL, 'aaa', 'bbb'], to: 'ccc' }
            { from: [SENTINEL, 'aaa', 'bbb', 'ccc'], to: 'ddd' }
            { from: ['aaa', 'bbb', 'ccc', 'ddd'], to: 'eee' }
            { from: ['bbb', 'ccc', 'ddd', 'eee'], to: 'fff' }
            { from: ['ccc', 'ddd', 'eee', 'fff'], to: 'ggg' }
            { from: ['ddd', 'eee', 'fff', 'ggg'], to: 'hhh' }
            { from: ['eee', 'fff', 'ggg', 'hhh'], to: 'iii' }
            { from: ['fff', 'ggg', 'hhh', 'iii'], to: SENTINEL }
            { from: ['ggg', 'hhh', 'iii', SENTINEL], to: SENTINEL }
            { from: ['hhh', 'iii', SENTINEL, SENTINEL], to: SENTINEL }
            { from: ['iii', SENTINEL, SENTINEL, SENTINEL], to: SENTINEL }
          ]

      describe 'learn()', ->
        it 'records each transition in state sequence', (done) ->
          model.learn ['aaa', 'bbbb', 'ccc', 'dddddd', 'eee', 'z'], ->
            async.parallel [
              (cb) -> storage.get([SENTINEL, SENTINEL], cb) # 0
              (cb) -> storage.get([SENTINEL, 'aaa'], cb) # 1
              (cb) -> storage.get(['aaa', 'bbbb'], cb) # 2
              (cb) -> storage.get(['bbbb', 'ccc'], cb) # 3
              (cb) -> storage.get(['ccc', 'dddddd'], cb) # 4
              (cb) -> storage.get(['dddddd', 'eee'], cb) # 5
              (cb) -> storage.get(['eee', 'z'], cb) # 6
              (cb) -> storage.get(['z', SENTINEL], cb) # 7
            ], (err, results) ->
              endMarker = {}
              endMarker[SENTINEL] = 1

              expect(err).to.not.exist
              expect(results[0]).to.deep.equal({aaa: 1})
              expect(results[1]).to.deep.equal({bbbb: 1})
              expect(results[2]).to.deep.equal({ccc: 1})
              expect(results[3]).to.deep.equal({dddddd: 1})
              expect(results[4]).to.deep.equal({eee: 1})
              expect(results[5]).to.deep.equal({z: 1})
              expect(results[6]).to.deep.equal(endMarker)
              expect(results[7]).to.deep.equal(endMarker)
              done()

        it 'ignores phrases with fewer than @min words', (done) ->
          model.learn ['aaa', 'bbb'], ->
            async.parallel [
              (cb) -> storage.get([SENTINEL, SENTINEL], cb) # 0
              (cb) -> storage.get([SENTINEL, 'aaa'], cb) # 1
              (cb) -> storage.get(['aaa', 'bbb'], cb) # 2
              (cb) -> storage.get(['bbb', SENTINEL], cb) # 3
            ], (err, results) ->
              expect(err).to.not.exist
              expect(results[0]).to.deep.equal({})
              expect(results[1]).to.deep.equal({})
              expect(results[2]).to.deep.equal({})
              expect(results[3]).to.deep.equal({})
              done()

        it 'does nothing for an empty list', (done) ->
          model.learn [], ->
            storage.get [SENTINEL, SENTINEL], (err, result) ->
              expect(err).to.not.exist
              expect(result).to.deep.equal({})
              done()

      describe 'generate()', ->
        it 'produces text by following stored transitions', (done) ->
          @timeout(10000)

          storage.incrementTransitions [
            { from: [SENTINEL, SENTINEL], to: 'a' }
            { from: [SENTINEL, 'a'], to: 'b' }
            { from: ['a', 'b'], to: 'c1' }
            { from: ['b', 'c1'], to: 'd1' }
            { from: ['c1', 'd1'], to: SENTINEL }
            { from: ['d1', SENTINEL], to: SENTINEL }
            { from: ['a', 'b'], to: 'c2' }
            { from: ['a', 'b'], to: 'c2' }
            { from: ['b', 'c2'], to: 'd2' }
            { from: ['c2', 'd2'], to: SENTINEL }
            { from: ['d2', SENTINEL], to: SENTINEL }
          ], (err) ->
            expect(err).to.not.exist

            occurrences =
              'a b c1 d1': 0
              'a b c2 d2': 0

            ITERATION_COUNT = 1000
            TOLERANCE = ITERATION_COUNT / 10

            generate = (n, cb) ->
              model.generate [], 10, (err, states) ->
                expect(err).to.not.exist
                occurrences[states.join ' ']++
                cb()
            async.times ITERATION_COUNT, generate, (err) ->
              expect(err).to.not.exist
              expect(occurrences['a b c1 d1']).to.be.closeTo(ITERATION_COUNT / 3, TOLERANCE)
              expect(occurrences['a b c2 d2']).to.be.closeTo(2 * ITERATION_COUNT / 3, TOLERANCE)
              done()

        it 'truncates phrases at max words', (done) ->
          storage.incrementTransitions [
            { from: [SENTINEL, SENTINEL], to: 'a' }
            { from: [SENTINEL, 'a'], to: 'b' }
            { from: ['a', 'b'], to: 'c' }
            { from: ['b', 'c'], to: 'd' }
            { from: ['c', 'd'], to: SENTINEL }
            { from: ['d', SENTINEL], to: SENTINEL }
          ], (err) ->
            expect(err).to.not.exist

            model.generate [], 3, (err, states) ->
              expect(err).to.not.exist
              expect(states).to.deep.equal ['a', 'b', 'c']
              done()

        describe 'with a seed', ->

          beforeEach (done) ->
            storage.incrementTransitions [
              { from: [SENTINEL, SENTINEL], to: 'a' }
              { from: [SENTINEL, 'a'], to: 'b' }
              { from: ['a', 'b'], to: 'c' }
              { from: ['b', 'c'], to: 'd' }
              { from: ['c', 'd'], to: SENTINEL }
              { from: ['d', SENTINEL], to: SENTINEL }
              { from: [SENTINEL, SENTINEL], to: '1' }
              { from: [SENTINEL, '1'], to: '2' }
              { from: ['1', '2'], to: '3' }
              { from: ['2', '3'], to: '4' }
              { from: ['3', '4'], to: SENTINEL }
              { from: ['4', SENTINEL], to: SENTINEL }
            ], done

          it 'uses a seed to begin the generated phrase', (done) ->
            model.generate ['2', '3'], 10, (err, states) ->
              expect(err).to.not.exist
              expect(states).to.deep.equal ['2', '3', '4']
              done()

          it 'handles seeds not present in the model', (done) ->
            model.generate ['nope'], 10, (err, states) ->
              expect(err).to.not.exist
              expect(states).to.deep.equal ['nope']
              done()

          it 'handles seeds longer than @ply', (done) ->
            model.generate ['foo', 'bar', 'b', 'c'], 10, (err, states) ->
              expect(err).to.not.exist
              expect(states).to.deep.equal ['foo', 'bar', 'b', 'c', 'd']
              done()

          it 'handles seeds shorter than @ply', (done) ->
            model.generate ['1'], 10, (err, states) ->
              expect(err).to.not.exist
              expect(states).to.deep.equal ['1', '2', '3', '4']
              done()

  generate(storageClass) for storageClass in storageClasses
