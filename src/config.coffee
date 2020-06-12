storageMap = require './storage'

intSetting = (hash, key, def) ->
  return def if not hash[key]? or hash[key].length is 0
  normalized = hash[key].replace /\s+/g, ''
  unless /^\d+$/.test normalized
    throw new Error("#{key} must be numeric: got [#{normalized}]")
  parseInt(normalized)

floatSetting = (hash, key, def) ->
  return def if not hash[key]? or hash[key].length is 0
  normalized = hash[key].replace /\s+/g, ''
  unless /^[\d.]+$/.test normalized
    throw new Error("#{key} must be numeric: got [#{normalized}]")
  parseFloat(normalized)

boolSetting = (hash, key, def) ->
  return def if not hash[key]? or hash[key].length is 0
  normalized = hash[key].toLowerCase().trim()
  if normalized in ['1', 'true', 't', 'yes', 'y']
    return true
  if normalized in ['0', 'false', 'f', 'no', 'n'] or normalized.length is 0
    return false
  throw new Error("#{key} must be 'true' or 'false': got [#{normalized}]")

listSetting = (hash, key, def) ->
  return def if not hash[key]? or hash[key].length is 0
  hash[key].split(/,+/)
    .map (each) ->
      each.trim()
    .filter (each) ->
      each.length isnt 0

enumSetting = (hash, key, choices, def) ->
  return def if not hash[key]? or hash[key].length is 0
  normalized = hash[key].toLowerCase().trim()
  if normalized not in choices
    throw new Error("#{key} must be one of #{choices.join ', '} but was '#{normalized}'")
  return normalized

stringSetting = (hash, key, def) ->
  return def if not hash[key]? or hash[key].length is 0
  hash[key]

module.exports = (hash) ->
  if hash.HUBOT_MARKOV_NOREVERSE?
    console.error "hubot-markov: Using removed option HUBOT_MARKOV_NOREVERSE."
    console.error "hubot-markov: Please set HUBOT_MARKOV_REVERSE_MODEL instead."

    hash.HUBOT_MARKOV_REVERSE_MODEL = boolSetting(hash, 'HUBOT_MARKOV_NOREVERSE', false).toString()

  return {
    ply: intSetting(hash, 'HUBOT_MARKOV_PLY', 1)
    learnMin: intSetting(hash, 'HUBOT_MARKOV_LEARN_MIN', 1)
    generateMax: intSetting(hash, 'HUBOT_MARKOV_GENERATE_MAX', 50)
    storageKind: enumSetting(hash, 'HUBOT_MARKOV_STORAGE', Object.keys(storageMap), 'memory')
    storageUrl: stringSetting(hash, 'HUBOT_MARKOV_STORAGE_URL', null)
    respondChance: floatSetting(hash, 'HUBOT_MARKOV_RESPOND_CHANCE', 0)
    defaultModel: boolSetting(hash, 'HUBOT_MARKOV_DEFAULT_MODEL', true)
    reverseModel: boolSetting(hash, 'HUBOT_MARKOV_REVERSE_MODEL', true)
    includeUrls: boolSetting(hash, 'HUBOT_MARKOV_INCLUDE_URLS', false)
    ignoreList: listSetting(hash, 'HUBOT_MARKOV_IGNORE_LIST', [])
    ignoreMessageList: listSetting(hash, 'HUBOT_MARKOV_IGNORE_MESSAGE_LIST', [])
    learningListenMode: stringSetting(hash, 'HUBOT_MARKOV_LEARNING_LISTEN_MODE', 'catch-all')
    respondListenMode: stringSetting(hash, 'HUBOT_MARKOV_RESPOND_LISTEN_MODE', 'catch-all')
    createUserModels: boolSetting(hash, 'HUBOT_MARKOV_CREATE_USER_MODELS', false)
    userModelBlackList: listSetting(hash, 'HUBOT_MARKOV_USER_MODEL_BLACKLIST', [])
    userModelWhiteList: listSetting(hash, 'HUBOT_MARKOV_USER_MODEL_WHITELIST', [])
  }
