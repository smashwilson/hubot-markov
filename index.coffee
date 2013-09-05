fs = require 'fs'
path = require 'path'

module.exports = (robot) ->
  scriptsPath = path.resolve(__dirname, 'src')
  fs.exists scriptsPath, (exists) ->
    if exists
      for script in fs.readdirSync(scriptsPath)
        robot.loadFile(scriptsPath, script)
        robot.parseHelp(path.join(scriptsPath, script))
