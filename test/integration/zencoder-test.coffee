app = require '../../app'
fs = require 'fs'
url = require 'url'
rest = require '../rest'

serverUrl = url.format(protocol: 'http', hostname: app.address().address, port: app.address().port, pathname: '/')

module.exports =
  testVideoUpload: (test)->
    videoFile = './test/data/waves.mov'

    rest.upload serverUrl,
      [videoFile],
      success: (files)=>
        video = files[0]

        checkStatus = ->
          console.log "Checking status of file: %s", video.id
          rest.get serverUrl + video.id + '.status', 
            success: (status)->
              console.log "Status: %s", status.status
              if status.status is 'finished'
                test.ok true
                test.done()
                return
              else if status.status is 'failed'
                test.ok false, "Video failed to render"
                return
              
              console.log "No status yet, trying again in 5sec"
              setTimeout(checkStatus, 5000)
        checkStatus()
