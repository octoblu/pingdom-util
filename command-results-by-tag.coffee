_             = require 'lodash'
colors        = require 'colors'
program       = require 'commander'
debug         = require('debug')('pingdom-util:command-results-by-tag')

PingdomService = require './src/pingdom-service'
packageJSON    = require './package.json'

program
  .version packageJSON.version
  .usage '[options] <hostname>'
  .option '-a, --app-key <string>', 'Pingdom app key. (env: PINGDOM_APP_KEY)'
  .option '-u, --username <string>', 'Pingdom Username. (env: PINGDOM_USERNAME)'
  .option '-p, --password <string>', 'Pingdom Password. (env: PINGDOM_PASSWORD)'

class Command
  constructor: ->
    process.on 'uncaughtException', @die
    { appKey, username, password } = @parseOptions()
    @pingdomService = new PingdomService { appKey, username, password }

  parseOptions: =>
    program.parse process.argv

    hostname = program.args[0]

    { appKey, username, password } = program

    appKey ?= process.env.PINGDOM_APP_KEY
    username ?= process.env.PINGDOM_USERNAME
    password ?= process.env.PINGDOM_PASSWORD

    @dieHelp new Error 'Missing PINGDOM_APP_KEY' unless appKey?
    @dieHelp new Error 'Missing PINGDOM_USERNAME' unless username?
    @dieHelp new Error 'Missing PINGDOM_PASSWORD' unless password?
    return { appKey, username, password }

  run: =>
    @pingdomService.resultsByTag { }, (error, results) =>
      return @die error if error?
      _.each results, (result, tag) =>
        info = "#{result.passes}/#{result.total} healthy checks"
        console.log colors.bold("##{tag}"), "#{result.percent} uptime", colors.gray info
      process.exit 0

  dieHelp: (error) =>
    program.outputHelp()
    return @die error

  die: (error) =>
    return process.exit(0) unless error?
    console.error error.stack
    process.exit 1

module.exports = Command
