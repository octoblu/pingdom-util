_             = require 'lodash'
path          = require 'path'
colors        = require 'colors'
program       = require 'commander'
url           = require 'url'
debug         = require('debug')('pingdom-util:command-configure')

PingdomService = require './src/pingdom-service'
packageJSON    = require './package.json'

program
  .version packageJSON.version
  .usage '[options] <hostname>'
  .option '--pathname <string>', 'Path to hit up when for healthcheck. Defaults to /healthcheck'
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

    { appKey, username, password, pathname } = program
    pathname ?= '/healthcheck'

    appKey ?= process.env.PINGDOM_APP_KEY
    username ?= process.env.PINGDOM_USERNAME
    password ?= process.env.PINGDOM_PASSWORD

    @dieHelp new Error 'Missing PINGDOM_APP_KEY' unless appKey?
    @dieHelp new Error 'Missing PINGDOM_USERNAME' unless username?
    @dieHelp new Error 'Missing PINGDOM_PASSWORD' unless password?
    @dieHelp new Error 'Missing hostname as first argument' unless hostname?
    @dieHelp new Error 'Missing pathname argument' unless pathname?
    pathname = "/#{pathname}" unless _.startsWith pathname, '/'

    parts = url.parse "https://#{hostname}#{pathname}"
    @dieHelp new Error "Invalid hostname '#{hostname}'" unless parts?.hostname?
    @dieHelp new Error "Invalid pathname '#{pathname}'" unless parts?.pathname?

    return { appKey, username, password, hostname, pathname }

  run: =>
    { hostname, pathname } = @parseOptions()
    @pingdomService.configure { hostname, pathname }, (error) =>
      return @die error if error?
      console.log colors.green('SUCCESS'), colors.white('it has been done')
      process.exit 0

  dieHelp: (error) =>
    program.outputHelp()
    return @die error

  die: (error) =>
    return process.exit(0) unless error?
    console.error error.stack
    process.exit 1

module.exports = Command
