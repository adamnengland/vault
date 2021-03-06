app = require '../../server'
url = require 'url'
sys = require 'util'
async = require 'async'
mime = require 'mime'
client = require '../../util/http-client'
fs = require 'fs'
hash = require '../../util/hash'

Config = require '../../config'
Secure = require '../../secure'
Profile = require '../../models/profile'
File = require '../../models/file'
VideoTranscoder = require '../../filters/zencoder'

VideoTranscoder.prototype.start = (file)->
  console.log "Bypassing Zencoder"

serverUrl = Secure.systemUrl()

zencoderResponse =  (thumbUrl, videoUrl)->
  "output":
      "thumbnails": [{
          "images": [{
              "format": "PNG",
              "url":thumbUrl,
          }],
          "label": "thumb"
      }],
      "state": "finished",
      "height": 640,
      "width": 480,
      "format": "mpeg4",
      "url": videoUrl,
      "duration_in_ms": 5000,
      "frame_rate": 25.0

failedZencoderResponse =  (thumbUrl, videoUrl)->
  "output":
      "state": "failed",
      "height": 640,
      "width": 480,
      "format": "mpeg4",
      "url": videoUrl,
      "duration_in_ms": 5000,
      "frame_rate": 25.0

module.exports =
  testVideoProfile: (test)->
    filename = './test/data/waves.mov'

    client.upload serverUrl, filename, (err, files)=>
      video = files[0]
      File.fetch video.id, (file)->
        test.equal file.profile().name, 'video'
        test.done()

  testVideoUpload: (test)->
    filename = './test/data/waves.mov'
    image = './test/data/han.jpg'
    start = new Date().getTime()

    client.upload serverUrl, filename, (err, files)=>
      end = new Date().getTime()
      console.log "Finished in #{end - start} millis"
      video = files[0]
      post = zencoderResponse(Secure.systemUrl(video.id), Secure.systemUrl(video.id))
      profile = new Profile('video', Config.profiles.video)
      formats = hash(profile.formats).filter((k,v)-> v.transcoder)
      q = async.queue (name, cb)->
        format = formats[name]
        client.postJson Secure.systemUrl(name + '/' + video.id), post, (err, data, response)=>
          test.equal response.statusCode, 200
          client.get Secure.systemUrl(name + '/' + video.id), (err, data, response)=>
            test.equal mime.lookup(hash(format.transcoder).first().format), response.headers['content-type']
            cb()
      , 2

      q.drain = ()->
        test.done()
      for name, format of formats
        q.push name

  testVideoProfileUpload: (test)->
    filename = './test/data/waves.mov'
    start = new Date().getTime()

    client.upload serverUrl, filename, { profile: 'stupeflix' }, (err, files)=>
      end = new Date().getTime()
      console.log "Finished in #{end - start} millis"
      video = files[0]
      post = zencoderResponse(Secure.systemUrl(video.id), Secure.systemUrl(video.id))
      profile = new Profile('stupeflix', Config.profiles.stupeflix)
      formats = hash(profile.formats).filter((k,v)-> v.transcoder)
      q = async.queue (name, cb)->
        format = formats[name]
        client.postJson Secure.systemUrl( name + '/' + video.id), post, (err, data, response)=>
          test.equal response.statusCode, 200
          client.get Secure.systemUrl(name + '/' + video.id), (err, data, response)=>
            test.equal mime.lookup(hash(format.transcoder).first().format), response.headers['content-type']
            cb()
      , 2

      q.drain = ()->
        test.done()
      for name, format of formats
        q.push name
  testVideoProfileDownload: (test)->
    filename = './test/data/waves.mov'
    start = new Date().getTime()

    client.upload serverUrl, filename, (err, files)=>
      video = files[0]
      client.postJson serverUrl, {url: Secure.systemUrl(video.id), filename: 'waves.mov', profile: 'stupeflix' }, (err, file)->
        post = zencoderResponse(Secure.systemUrl(file.id), Secure.systemUrl(file.id))
        profile = new Profile('stupeflix', Config.profiles.stupeflix)
        formats = hash(profile.formats).filter((k,v)-> v.transcoder)
        q = async.queue (name, cb)->
          format = formats[name]
          client.postJson Secure.systemUrl( name + '/' + file.id), post, (err, data, response)=>
            test.ifError err
            test.equal response.statusCode, 200
            client.get Secure.systemUrl(name + '/' + file.id), (err, data, response)=>
              test.equal mime.lookup(hash(format.transcoder).first().format), response.headers['content-type']
              cb()
        , 2

        q.drain = ()->
          test.done()
        for name, format of formats
          q.push name

  testFailedStatus: (test)->
    filename = './test/data/waves.mov'
    start = new Date().getTime()

    client.upload serverUrl, filename, { profile: 'stupeflix' }, (err, files)=>
      end = new Date().getTime()
      console.log "Finished in #{end - start} millis"
      video = files[0]
      post = failedZencoderResponse(Secure.systemUrl(video.id), Secure.systemUrl(video.id))
      count = 0
      profile = new Profile('stupeflix', Config.profiles.stupeflix)
      formats = hash(profile.formats).filter((k,v)-> v.transcoder)
      for name, format of formats
        client.postJson Secure.systemUrl(name + '/' + video.id), post, (err, data, response)=>
            test.equal response.statusCode, 200
            count++
            if count == hash(formats).keys().length
              client.json Secure.systemUrl(video.id + '.status'), (err, data)=>
                status = data
                test.equal status.status, 'failed'
                test.equal data.formats[0].status, 'failed'
                test.done()

