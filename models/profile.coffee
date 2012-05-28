hash = require '../util/hash'
array = require '../util/array'
util = require 'util'
Config = require '../config'

class Profile
  constructor: (@name, profile = {})->
    @extensions = profile.extensions || []
    @metaFilterType = profile.metaFilter
    @formats = hash(profile).clone()
    delete @formats['extensions']
    delete @formats['metaFilter']
  transcoder: (formatName)->
    if format = @formats[formatName]
      return @_resolveFilter(hash(format.transcoder).firstKey())
  transcode: (file)->
    for name, format of @formats
      if format.transcoder
        transcoder = @_resolveFilter(hash(format.transcoder).firstKey())
        transcoder.start file
        break
  metaFilter: (file, callback)->
    if @metaFilterType
      meta = @_resolveFilter @metaFilterType
      meta.filter file, ->
        callback(file)
    else
      callback(file)
  filter: (file, formatName, callback)->
    format = @formats[formatName]
    if format
      console.log "Getting Filter for Format: %s", formatName
      console.log util.inspect(format.filter)
    if format and format.filter
      filter = @_resolveFilter(hash(format.filter).firstKey(), formatName, hash(format.filter).first())
      filter.filter file, ->
        callback(file)
    else
      callback(file)
  extension: (formatName)->
    if format = @formats[formatName]
      if transcoder = format.transcoder
        return hash(transcoder).first().format
      if filter = format.filter
        if file =  hash(filter).first().file
          return array(file.split('.')).last()
  @default: (filename)->
    for name, profile of Config.profiles
      if profile.extensions and array(filename.split('.')).last() in profile.extensions
        return name
    'default'
  _resolveFilter: (filterName, format, settings)->
    console.log "Filter Name: " +filterName
    filterPath = filterName.replace(/(.)([A-Z])/, '$1-$2').toLowerCase()
    console.log "Filter Path: " +filterPath
    filterClass = require "../models/#{filterPath}"
    console.log "Filter Class: " +filterClass
    new filterClass(format, settings)

module.exports = Profile
