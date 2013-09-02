fs = require 'fs'
path = require 'path'

module.exports = (robot) ->
  scriptsPath = path.resolve(__dirname, 'src')
  fs.exists path, (exists) ->
    if exists
      for script in fs.readdirSync(path)
        robot.loadFile(path, file)
        robot.parseHelp(path.join(path, file))
