exports.words = (input) -> word for word in input.split /\s+/ when word.length > 0

exports.reverse = (input) -> input.slice().reverse()
