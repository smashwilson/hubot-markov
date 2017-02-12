{expect} = require 'chai'

preprocessor = require '../src/preprocessor'

describe 'preprocessors', ->
  describe '.words', ->
    it 'splits a line of text into whitespace-separated, nonempty words', ->
      ws = preprocessor.words 'this is a line of text'
      expect(ws).to.deep.equal ['this', 'is', 'a', 'line', 'of', 'text']

    it 'ignores repeated whitespace', ->
      ws = preprocessor.words "separated   by    \n\r lots   of  whitespace"
      expect(ws).to.deep.equal ['separated', 'by', 'lots', 'of', 'whitespace']

    it 'ignores leading and trailing whitespace', ->
      ws = preprocessor.words "   with leading and trailing   "
      expect(ws).to.deep.equal ['with', 'leading', 'and', 'trailing']

    it 'returns an empty list for an empty line of text', ->
      expect(preprocessor.words '').to.deep.equal []

  describe '.reverse', ->
    it 'reverses its input', ->
      ws = preprocessor.reverse ['this', 'is', 'a', 'line', 'of', 'text']
      expect(ws).to.deep.equal ['text', 'of', 'line', 'a', 'is', 'this']
