_       = require 'lodash'
request = require 'request'
debug   = require('debug')('pingdom-util:pingdom-service')

class PingdomService
  constructor: ({ @appKey, @username, @password }) ->
    throw new Error 'Missing appKey' unless @appKey?
    throw new Error 'Missing username' unless @username?
    throw new Error 'Missing password' unless @password?
    @baseUrl = 'https://api.pingdom.com/api/2.0'

  configure: ({ hostname, pathname }, callback) =>
    @_get { hostname, pathname }, (error, check) =>
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

  _get: ({ hostname, pathname }, callback) =>
    @_request { method: 'GET', uri: '/checks' }, (error, body) =>
      return callback error if error?
      { checks } = body
      debug 'found checks', _.size(checks)
      check = _.find checks, { hostname }
      debug 'found check', check
      callback null, check

  _request: ({ method, uri, body }, callback) =>
    options = {
      method
      uri
      @baseUrl
      form: body ? true
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
      callback null, JSON.parse body

module.exports = PingdomService
