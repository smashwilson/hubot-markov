{expect} = require 'chai'

processors = require '../src/processors'

describe 'processors', ->
  describe '.words', ->
    it 'pre splits a line of text into whitespace-separated, nonempty words', ->
      ws = processors.words.pre 'this is a line of text'
      expect(ws).to.deep.equal ['this', 'is', 'a', 'line', 'of', 'text']

    it 'pre ignores repeated whitespace', ->
      ws = processors.words.pre "separated   by    \n\r lots   of  whitespace"
      expect(ws).to.deep.equal ['separated', 'by', 'lots', 'of', 'whitespace']

    it 'pre ignores leading and trailing whitespace', ->
      ws = processors.words.pre "   with leading and trailing   "
      expect(ws).to.deep.equal ['with', 'leading', 'and', 'trailing']

    it 'pre returns an empty list for an empty line of text', ->
      expect(processors.words.pre '').to.deep.equal []

    it 'post joins words with single spaces', ->
      tokens = ['this', 'is', 'a', 'line', 'of', 'text']
      expect(processors.words.post tokens).to.equal 'this is a line of text'

  describe '.reverseWords', ->
    it 'pre reverses its input', ->
      ws = processors.reverseWords.pre 'this is a line of text'
      expect(ws).to.deep.equal ['text', 'of', 'line', 'a', 'is', 'this']

    it 'post reverses tokens back', ->
      tokens = ['text', 'of', 'line', 'a', 'is', 'this']
      expect(processors.reverseWords.post tokens).to.equal 'this is a line of text'
