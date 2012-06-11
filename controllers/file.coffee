mime = require 'mime'
fs = require 'fs'
util = require 'util'
path = require 'path'
download = require '../util/download'

File = require '../models/file'
Config = require '../config'
Synchronizer = require '../models/synchronizer'

class FileController
  constructor: (@app)->
  serve: (req, res, next) =>
    id = req.params.fileId
    format = req.params.format

    File.fetch id, format, (file)=>
      fs.stat file.path(format), (err, stat)=>
        if err
          res.send(404)
        else
          res.writeHead 200,
            'Content-Type': mime.lookup(file.filename(format)),
            'Content-Length': stat.size
          
          read = fs.createReadStream file.path(format)
          util.pump read, res
  upload: (req, res, next) =>
    created = []

    for key, upload of req.files
      do (key, upload) =>
        if upload.name
          File.create upload.path, upload.name, req.param('profile'), (file)=>
            created.push file.json()

            if created.length == Object.keys(req.files).length
              res.end JSON.stringify(created)
            file.profile().transcode file
            Synchronizer.sync file, @app.registry.slaves
  download: (req, res, next) =>
    json = req.body
    console.log json

    filePath = path.join(Config.tmpDir, json.filename)
    download json.url, filePath, ->
      if json.format && json.id
        File.fetch json.id, null, (file)->
          fs.rename filePath, file.path(json.format), ()->
            res.end JSON.stringify(file.json())
      else
        File.create filePath, json.filename, json.profile, json.id, (file)=>
          res.end JSON.stringify(file.json())
          unless json.id
            file.profile().transcode file
            Synchronizer.sync file, @app.registry.slaves
  finish: (req, res, next) =>
    id = req.params.fileId
    format = req.params.format

    notification = req.body

    File.fetch id, format, (file)=>
      if transcoder = file.profile().transcoder(format)
        transcoder.finish file, notification, format, =>
          res.end JSON.stringify(file.json())
          Synchronizer.sync file, @app.registry.slaves, format
      else
        res.end new Error("No transcoder")
  status: (req, res, next) =>
    id = req.params.fileId
    format = req.params.format

    File.fetch id, format, (file)=>
      res.send(file.json())
  delete: (req, res, next) =>
    id = req.params.fileId

    File.delete id, (file)=>
      res.end("ok")


module.exports = FileController
