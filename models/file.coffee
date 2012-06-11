uuid = require 'node-uuid'
fs = require 'fs-extra'
path = require 'path'
mkdirp = require 'mkdirp'
touch = require '../util/touch'
array = require '../util/array'
hash = require '../util/hash'

Config = require '../config'
Profile = require './profile'

class File
  constructor: (@id, @originalName) ->
    if @originalName
      @contents = []
    else
      @originalName = array(@refresh()).match ///\.original\.\w+$///

  # Filesystem
  directory: () ->
    return @dir ||= File.directory(@id)
  filename: (format = 'original')->
    return @originalName if format == 'original' && @originalName
    throw new Error("Invalid format: #{format}") unless format.match /^[\w\.]+$/

    name = @findFormat format
    unless name || format == 'original'
      name = @rename format

    return name
  path: (format) ->
    if @filename(format) && @directory()
      return path.join @directory(), @filename(format)
    else
      throw new Error("#{@id} Not Found")
  findFormat: (format)->
    array(@contents).match ///#{@prefix()}\.#{format}///
  rename: (format)->
    return "#{@prefix()}.#{format}.#{@extension(format)}"
  prefix: ()->
    return @originalName.split('.')[0]
  extension: (format)->
    if ext = @profile().extension(format)
      return ext
    return array(@originalName.split('.')).last()
  join: (paths)->
    path.join @directory(), paths
  
  # Metadata
  get: (name)->
    value = array(@contents).match ///#{name}///
    value.toString().split('.')[0] if value
  set: (pair, cb)->
    key = hash(pair).firstKey()
    name = "#{pair[key]}.#{key}"
    @contents.push(name) unless name in @contents

    touch @join(name), cb
  refresh: ()->
    @contents = fs.readdirSync(@directory())
  values: (name, delim = 'x')->
    value = @get(name)
    value.split(delim) if value
  status: ->
    for name, format of @profile().formats
      return 'failed' if @get("failed.#{format}.status$")
    return @get(".status$")
  json: ->
    size = @values('size')
    duration = @get('duration')
    status = @status()
    {
      id: @id
      duration: duration
      width: size[0] if size
      height: size[1] if size
      status: status
      filename: @filename()
    }
  profile: ->
    p = @get ".profile$"
    new Profile(p, Config.profiles[p])
  meta: ->
    console.log @contents
    p for p in @contents when p.match /(status|size|duration)$/

  # Static
  @directory: (id)->
    throw new Error("Invalid id: #{id}") unless id.match /^[\w-]+$/

    first = id.substring(0,2)
    second = id.substring(2,4)

    path.join(Config.mediaDir, first, second, id)
  @create: (args..., callback) ->
    filePath = args[0]
    name = args[1]
    profile = args[2]
    id = args[3]
    console.log "Creating with id: #{id}"

    id ||= uuid.v4()
    console.log "Still creating with id: #{id}"
    originalName =  name.replace(/\ /, '-').replace(/[^A-Za-z0-9\.\-_]/, '').replace(/(.*\.)(\w+)$/, '$1original.$2').toLowerCase()

    file = new File(id, originalName)

    mkdirp.sync(file.directory())
    fs.rename filePath, file.path(), ()->
      file.set profile: profile || Profile.default(name), ->
        console.log "Profile: " + file.profile().name
        file.profile().metaFilter file, callback

  @fetch: (id, format, callback) ->
    file = new File(id)
    file.profile().filter file, format, callback

  @delete: (id, callback)->
    File.fetch id, 'original', (file)->
      fs.rename file.path(), path.join(Config.deleteDir, id), callback

module.exports = File
