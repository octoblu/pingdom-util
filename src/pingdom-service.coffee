_       = require 'lodash'
async   = require 'async'
request = require 'request'
moment  = require 'moment'
debug   = require('debug')('pingdom-util:pingdom-service')

class PingdomService
  constructor: ({ @appKey, @username, @password }) ->
    throw new Error 'Missing appKey' unless @appKey?
    throw new Error 'Missing username' unless @username?
    throw new Error 'Missing password' unless @password?
    @baseUrl = 'https://api.pingdom.com/api/2.0'

  configure: ({ hostname, pathname }, callback) =>
    @_getCheck { hostname }, (error, check) =>
      return callback error if error?
      return callback null if check?
      @_create { hostname, pathname }, callback

  _create: ({ hostname, pathname }, callback) =>
    body = {
      name: hostname
      host: hostname
      type: 'http'
      resolution: 1
      url: pathname
      encryption: true
      contactids: '11058966,10866214'
      sendtoemail: true
      use_legacy_notifications: true
    }
    @_request { method: 'POST', uri: '/checks', body }, (error, response) =>
      return callback error if error?
      debug 'response', response
      callback null

  resultsByTag: ({ to, from }, callback) =>
    @_getChecksByTag {}, (error, tags) =>
      return callback error if error?
      async.mapValuesLimit tags, 10, async.apply(@_getResultsForTag, { to, from }), callback

  _getResultsForTag: (options, checks, key, callback) =>
    debug 'get results for tag'
    async.mapValuesLimit checks, 20, async.apply(@_getResultsForCheck, options), (error, allResults) =>
      return callback error if error?
      minutes = {}
      _.each _.values(allResults), (checkResults) =>
        _.each checkResults, (result) =>
          time = @_getTime result
          up = result.status == 'up'
          minutes[time] ?= { up, count: 0 }
          minutes[time].up = up if minutes[time].up
      total = _.size _.values(minutes)
      passes = _.size _.filter(_.values(minutes), 'up')
      failures = total - passes
      percent = "#{_.round((passes / total) * 100, 3)}%"
      callback null, {
        percent,
        total,
        failures,
        passes,
      }

  _getResultsForCheck: ({ offset, to, from, previous, i=0 }, { id }, key, callback) =>
    limit = 1000
    debug 'get results options', { i, to, from, offset, limit }
    options = _.pickBy { offset, to, from, limit }
    @_request { method: 'GET', uri: "/results/#{id}", qs: options }, (error, body) =>
      return callback error if error?
      results = _.get body, 'results', []
      count = _.size results
      results = _.union results, previous if previous?
      debug 'results count', count
      if count < limit
        return callback null, results
      i += 1
      count = _.size results
      @_getResultsForCheck { offset: count, to, from, previous: results, i }, { id }, key, callback

  _getTime: ({ time }) =>
    return time - (time % (60))

  _getChecksByTag: ({}, callback) =>
    options = { include_tags: true }
    @_request { method: 'GET', uri: '/checks', qs: options }, (error, body) =>
      return callback error if error?
      { checks } = body
      tags = {}
      _.each checks, (check) =>
        { id } = check
        _.each check.tags, ({ name }) =>
          debug 'found tag', { name, id }
          tags[name] ?= {}
          tags[name][id] = check
      debug 'found tags', tags
      callback null, tags

  _getCheck: ({ hostname }, callback) =>
    @_request { method: 'GET', uri: '/checks' }, (error, body) =>
      return callback error if error?
      { checks } = body
      debug 'found checks', _.size(checks)
      check = _.find checks, { hostname }
      debug 'found check', check
      callback null, check

  _request: ({ method, uri, body, qs }, callback) =>
    options = {
      method
      uri
      @baseUrl
      form: body ? true
      qs
      headers: {
        'App-Key': @appKey
      }
      auth: {
        @username
        @password
      }
    }
    debug 'pingdom request options', options
    request options, (error, response, body) =>
      debug 'pingdom response', { error, statusCode: response?.statusCode }
      return callback error if error?
      return callback new Error('Invalid response') if response.statusCode > 499
      body = JSON.parse body
      return callback new Error _.get(body, 'error.errormessage') if response.statusCode > 399
      callback null, body

module.exports = PingdomService
