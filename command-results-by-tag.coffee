_             = require 'lodash'
colors        = require 'colors'
program       = require 'commander'
moment        = require 'moment'
debug         = require('debug')('pingdom-util:command-results-by-tag')

PingdomService = require './src/pingdom-service'
packageJSON    = require './package.json'

program
  .version packageJSON.version
  .usage '[options] <hostname>'
  .option '-t, --to <date-string>', 'End of period. Defaults to current time. (must be parsable by moment())'
  .option '-f, --from <date-string>', 'Start of period. Defaults to 1 day ago. (must be parsable by moment())'
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
    { to, from } = program

    appKey ?= process.env.PINGDOM_APP_KEY
    username ?= process.env.PINGDOM_USERNAME
    password ?= process.env.PINGDOM_PASSWORD

    @dieHelp new Error 'Missing PINGDOM_APP_KEY' unless appKey?
    @dieHelp new Error 'Missing PINGDOM_USERNAME' unless username?
    @dieHelp new Error 'Missing PINGDOM_PASSWORD' unless password?
    to = @parseDate(to)
    from = @parseDate(from)
    return { appKey, username, password, to, from }

  parseDate: (time) =>
    return unless time?
    time = _.toNumber(time) if _.isNumber(_.toNumber(time))
    date = moment(time)
    return date.unix() unless date.format('YYYY') == '1970'
    return time

  run: =>
    { to, from } = @parseOptions()
    @pingdomService.resultsByTag { to, from }, (error, results) =>
      return @die error if error?
      lines = []
      _.each results, (result, tag) =>
        lines.push { result, tag }
      lines = _.sortBy lines, 'tag'
      _.each lines, ({ result, tag }) =>
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
