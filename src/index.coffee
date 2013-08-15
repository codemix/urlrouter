QS = require "querystring"
URL = require "url"


stringifyURL = (item) ->
  url = []
  if item.hostname
    if item.protocol
      url.push "#{item.protocol}//"
    else
      url.push '//'
    url.push item.hostname
    if item.port
      url.push ":#{item.port}"
  if item.pathname
    url.push item.pathname
  else
    url.push "/"
  if item.query
    if item.query is String item.query
      url.push "?#{item.query}"
    else
      url.push "?#{QS.stringify item.query}"
  if item.hash
    url.push "#{item.hash}"
  url.join ''


###
A URL Router.
###
module.exports = class Router
  ###
  Configure the router
  ###
  constructor: (rules) ->
    @rules = []
    @add rule for rule in rules if rules?

  ###
  Dispatches a request for the given URL
  ###
  dispatch: (url) ->
    url = @normalizeUrl url
    for [parse, creator, handler] in @rules
      if (options = parse url)
        return handler options
    false

  ###
  Parses a given URL
  ###
  parseUrl: (url) ->
    url = @normalizeUrl url
    for [parse, creator, handler] in @rules
      if (options = parse url)
        return options
    false

  ###
  Creates a URL based on the given options
  ###
  createUrl: (options) ->
    for [parse, creator, handler] in @rules
      if (url = creator options)
        return url
    false

  ###
  Normalize a URL
  ###
  normalizeUrl: (url) ->
    url = URL.parse url if url is String url
    url.query = QS.parse url.query if url.query is String url.query
    url

  ###
  Adds a URL rule
  ###
  add: (pattern, [defaultParams]..., handler) ->
    defaultParams or= {}
    [parser, creator] = @processPattern pattern, defaultParams
    @rules.push [parser, creator, handler]
    this

  ###
  Process a pattern and returns a url parser and a url creator
  ###
  processPattern: (pattern, defaultParams) ->
    [re, patterns, names] = @extractPatternReferences pattern
    parser = @urlParser re, names, defaultParams
    creator = @urlCreator patterns, defaultParams
    [parser, creator]


  ###
  Returns a function that can parse URLs that match the given regex
  ###
  urlParser: (re, names, defaultParams) ->
    (url) ->
      matches = re.exec url.pathname
      return false unless matches?
      params = url.query
      for name, i in names
        params[name] = matches[i + 1]
      if defaultParams?
        for name, value of defaultParams
          params[name] or= value
      if url.hash
        params['#'] = url.hash.slice 1
      params

  ###
  Returns a function that can create URLs for the given patterns
  ###
  urlCreator: (patterns, defaultParams) ->
    parts = []
    matchers = {}
    for part in patterns
      unless Array.isArray part
        parts.push part
        continue
      [name, pattern] = part
      parts.push [name]
      matchers[name] = new RegExp "^#{pattern}$"

    (options = {}) ->
      pathParts = []
      copied = []
      for part in parts
        if Array.isArray part
          [name] = part
          if options[name]?
            return false unless matchers[name].test String options[name]
            pathParts.push options[name]
            copied.push name
          else if defaultParams?[name]?
            pathParts.push defaultParams[name]
          else
            return false
        else
          pathParts.push part
      url =
        pathname: "/#{pathParts.join ''}"
        query: {}
        toString: -> stringifyURL this
      if options['#']?
        url.hash = "##{options['#']}"
      for name, value of options
        url.query[name] = value unless name is '#' or ~copied.indexOf name

      url

  ###
  Extract the pattern references and return an array
  containing a regex and a list of reference names
  ###
  extractPatternReferences: (pattern) ->
    pattern = pattern.slice 1 if pattern.charAt(0) is '/'
    pattern = pattern.slice 0, pattern.length - 1 if pattern.charAt(pattern.length - 1) is '/'
    referencePattern = /([^<]+)?<(\w+)(:([^>]+))?>([^<]+)?/g
    escaper = /[-[\]{}()*+?.,\\^$|#\s]/g
    parts = []
    patterns = []
    names = []
    while (matches = referencePattern.exec pattern)?
      if matches[1]?
        prefix = matches[1].replace escaper, "\\$&"
      else
        prefix = ''
      name = matches[2]

      if matches[4]?
        matches[4] = "(#{matches[4]})" unless /^\((.*)\)$/.test matches[4]
      else
        matches[4] = '(\\w+)'
      regexPart = matches[4]

      if matches[5]?
        suffix = matches[5].replace escaper, "\\$&"
      else
        suffix = ''
      names.push name
      parts.push prefix, regexPart, suffix
      patterns.push prefix, [name, regexPart], suffix

    parts.push pattern.replace escaper, "\\$&" if names.length is 0
    [(new RegExp "^\/#{parts.join('')}"), patterns, names]

