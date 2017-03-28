exports.identity =
  pre: (input) -> input
  post: (output) -> output

exports.words =
  pre: (input) -> word for word in input.split /\s+/ when word.length > 0
  post: (output) -> output.join ' '

exports.reverseWords =
  pre: (input) -> exports.words.pre(input).reverse()
  post: (output) -> exports.words.post(output.slice().reverse())
