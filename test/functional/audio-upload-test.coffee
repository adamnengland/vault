app = require('../../server')
url = require 'url'
sys = require 'util'
client = require '../../util/http-client'
fs = require 'fs'
hash = require '../../util/hash'

Config = require '../../config'
Secure = require '../../secure'
Profile = require '../../models/profile'
VideoTranscoder = require '../../filters/zencoder'

VideoTranscoder.prototype.start = (file)->
  console.log "Bypassing Zencoder"

zencoderResponse =  (thumbUrl, audioUrl)->
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
      "format": "mp3",
      "url": audioUrl,
      "duration_in_ms": 5000,
      "frame_rate": 25.0


module.exports =

  testAudioProfileUpload: (test)->
    filename = './test/data/audio.flv'
    image = './test/data/han.jpg'
    start = new Date().getTime()

    client.upload Secure.systemUrl(), filename, { profile: 'audio' }, (err, files)=>
        end = new Date().getTime()
        audio = files[0]
        post = zencoderResponse(Secure.apiUrl() + audio.id, Secure.apiUrl() + audio.id)
        count = 0
        profile = new Profile('video', Config.profiles.audio)
        formats = hash(profile.formats).filter((k,v)-> v.transcoder)
        for name, format of formats
          client.postJson Secure.systemUrl(name + '/' + audio.id), post, (err, data, response)=>
              test.equal response.statusCode, 200
              count++
              if count == hash(formats).keys().length
                client.json Secure.systemUrl(audio.id + '.status'), (err, json)=>
                  console.log json
                  test.equal json.status, 'finished'
                  test.done()

