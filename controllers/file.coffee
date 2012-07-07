mime = require 'mime'
fs = require 'fs'
util = require 'util'
path = require 'path'
download = require '../util/download'
json = require '../util/json'

File = require '../models/file'
Config = require '../config'
Synchronizer = require '../models/synchronizer'

class FileController
  constructor: (@app)->
  serve: (req, res, next) =>
    id = req.params.fileId
    format = req.params.format
    options = json.parse(req.params.options) if req.params.options

    req.locals.file.filter format, options, (filePath)=>
      fs.stat filePath, (err, stat)=>
        if err
          console.error err
          res.send(404)
        else
          res.writeHead 200,
            'Content-Type': mime.lookup(filePath),
            'Content-Length': stat.size
          
          read = fs.createReadStream filePath
          util.pump read, res
  upload: (req, res, next) =>
    created = []

    for key, upload of req.files
      do (key, upload) =>
        if upload.name
          File.create upload.path, upload.name, profile: req.param('profile'), public: req.param('public'), (file)=>
            created.push file.json()

            if created.length == Object.keys(req.files).length
              res.end JSON.stringify(created)
            file.profile().transcode file
            Synchronizer.sync file, @app.registry
  download: (req, res, next) =>
    params = req.body

    filePath = path.join(Config.tmpDir, params.filename)
    download params.url, filePath, =>
      File.create filePath, params.filename, profile: params.profile, (file)=>
        res.end JSON.stringify(file.json())
        file.profile().transcode file
        Synchronizer.sync file, @app.registry
  finish: (req, res, next) =>
    file = req.locals.file
    format = req.params.format

    notification = req.body

    if transcoder = file.profile().transcoder(format)
      transcoder.finish file, notification, format, =>
        res.end JSON.stringify(file.json())
        Synchronizer.sync file, @app.registry
    else
      res.end new Error("No transcoder")
  status: (req, res, next) =>
    file = req.locals.file
    format = req.params.format

    res.send(file.json())
  delete: (req, res, next) =>
    file = req.locals.file

    file.delete (file)=>
      res.end("ok")
  crossdomain: (req, res, next)=>
    res.end '<?xml version="1.0"?><!DOCTYPE cross-domain-policy SYSTEM "http://www.macromedia.com/xml/dtds/cross-domain-policy.dtd"><cross-domain-policy><allow-access-from domain="*" secure="false" /> <allow-http-request-headers-from domain="*" headers="*"/></cross-domain-policy>'


module.exports = FileController
