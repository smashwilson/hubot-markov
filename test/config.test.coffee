{expect} = require 'chai'
config = require '../src/config'

describe 'config', ->
  describe 'numeric settings', ->
    it 'accepts a positive integer', ->
      settings = config {HUBOT_MARKOV_PLY: '5'}
      expect(settings.ply).to.equal(5)

    it 'discards whitespace', ->
      settings = config {HUBOT_MARKOV_PLY: '  100 \t 20\t\t \r\n'}
      expect(settings.ply).to.equal(10020)

    it 'throws an error on non-numeric input', ->
      expect ->
        config {HUBOT_MARKOV_PLY: '   504 nope 3 \t'}
      .to.throw /HUBOT_MARKOV_PLY must be numeric/

    it 'falls back to the default on a missing key', ->
      settings = config {}
      expect(settings.ply).to.equal(1)

    it 'falls back to the default on an empty key', ->
      settings = config {HUBOT_MARKOV_PLY: ''}
      expect(settings.ply).to.equal(1)

  describe 'boolean settings', ->
    generate = (settingValue, expectedOutput) ->
      it "accepts '#{settingValue}' as #{expectedOutput}", ->
        expect(config({HUBOT_MARKOV_REVERSE_MODEL: settingValue}).reverseModel).to.equal(expectedOutput)

    for positive in ['true', 't', 'yes', 'y', '1']
      for eachCase in [positive, positive.toUpperCase()]
        generate(eachCase, true)

    for negative in ['false', 'f', 'no', 'n', '0']
      for eachCase in [negative, negative.toUpperCase()]
        generate(eachCase, false)

    it 'throws an error on unrecognized input', ->
      expect ->
        config {HUBOT_MARKOV_REVERSE_MODEL: '47'}
      .to.throw /HUBOT_MARKOV_REVERSE_MODEL must be 'true' or 'false'/

    it 'falls back to the default on a missing key', ->
      expect(config({}).reverseModel).to.be.true

    it 'falls back to the default on an empty key', ->
      expect(config({HUBOT_MARKOV_REVERSE_MODEL: ''}).reverseModel).to.be.true

    it 'can default to "false"', ->
      expect(config({HUBOT_MARKOV_INCLUDE_URLS: ''}).includeUrls).to.be.false

  describe 'list settings', ->
    it 'accepts a comma-delimited list', ->
      settings = config {HUBOT_MARKOV_IGNORE_LIST: 'a,b,c,d'}
      expect(settings.ignoreList).to.deep.equal(['a', 'b', 'c', 'd'])

    it 'trims any whitespace around each item', ->
      settings = config {HUBOT_MARKOV_IGNORE_LIST: ' a  , b  , c    \t, d  \r\n'}
      expect(settings.ignoreList).to.deep.equal(['a', 'b', 'c', 'd'])

    it 'ignores empty leading or trailing items', ->
      settings = config {HUBOT_MARKOV_IGNORE_LIST: ',a,b,c,d,'}
      expect(settings.ignoreList).to.deep.equal(['a', 'b', 'c', 'd'])

  describe 'enum settings', ->
    it 'accepts any pre-listed value', ->
      settings = config {HUBOT_MARKOV_STORAGE: 'redis'}
      expect(settings.storageKind).to.equal('redis')

    it 'rejects an unrecognized value', ->
      expect ->
        config {HUBOT_MARKOV_STORAGE: 'the cloud'}
      .to.throw /HUBOT_MARKOV_STORAGE must be one of/

    it 'falls back to the default on a missing key', ->
      expect(config({}).storageKind).to.equal('memory')

    it 'falls back to the default on an empty key', ->
      expect(config({HUBOT_MARKOV_STORAGE: ''}).storageKind).to.equal('memory')

  describe 'string settings', ->
    it 'passes the setting through as-is', ->
      settings = config {HUBOT_MARKOV_STORAGE_URL: 'this  \t IS the URL'}
      expect(settings.storageUrl).to.equal('this  \t IS the URL')

    it 'falls back to the default on a missing key', ->
      expect(config({}).storageUrl).to.be.null

    it 'falls back to the default on an empty key', ->
      expect(config({HUBOT_MARKOV_STORAGE_URL: ''}).storageUrl).to.be.null
