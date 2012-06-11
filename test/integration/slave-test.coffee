fs = require 'fs'
request = require 'request'
rest = require '../rest'
exec  = require('child_process').exec
File = require '../../models/file'
Config = require '../../config'

server1 = exec 'coffee app.coffee'
serverUrl1 = "http://#{Config.serverHost}:7000/"
masterUrl = "http://#{Config.serverHost}:7000/"
console.log "Testing with URL1: %s", serverUrl1
server1.stdout.on 'data', (data)->
  console.log("[Server 1 : out] #{data}")
server1.stderr.on 'data', (data)->
  console.log("[Server 1 : err] #{data}")

server2 = exec "coffee app.coffee --port 7001 --tmp-dir /tmp/uploads2 --media-dir /tmp/media2 --master-url #{serverUrl1}"
serverUrl2 = "http://#{Config.serverHost}:7001/"
console.log "Testing with URL2: %s", serverUrl2
server2.stdout.on 'data', (data)->
  console.log("[Server 2 : out] #{data}")
server2.stderr.on 'data', (data)->
  console.log("[Server 2 : err] #{data}")

server3 = exec "coffee app.coffee --port 7002 --tmp-dir /tmp/uploads3 --media-dir /tmp/media3 --master-url #{serverUrl1}"
serverUrl3 = "http://#{Config.serverHost}:7002/"
console.log "Testing with URL3: %s", serverUrl3
server3.stdout.on 'data', (data)->
  console.log("[Server 3 : out] #{data}")
server3.stderr.on 'data', (data)->
  console.log("[Server 3 : err] #{data}")

module.exports =
  testAutoRegister: (test)->
    # Wait for auto register
    setTimeout ->
      request.get serverUrl1 + 'registry', (err, response, body)=>
        console.log body
        test.ifError err
        registry = JSON.parse body
        test.equal response.headers['content-type'], 'application/json'
        test.equal masterUrl, registry.master
        test.equal 2, registry.slaves.length
        test.ok serverUrl2 in registry.slaves
        test.ok serverUrl3 in registry.slaves
        test.done()
    , 500

  testRegistrySyncSlave1: (test)->
    request.get serverUrl2 + 'registry', (err, response, body)=>
      test.ifError err
      registry = JSON.parse body
      test.equal response.headers['content-type'], 'application/json'
      test.equal masterUrl, registry.master
      test.equal 2, registry.slaves.length
      test.ok serverUrl2 in registry.slaves
      test.ok serverUrl3 in registry.slaves
      test.done()

  testRegistrySyncSlave2: (test)->
    request.get serverUrl3 + 'registry', (err, response, body)=>
      test.ifError err
      registry = JSON.parse body
      test.equal response.headers['content-type'], 'application/json'
      test.equal masterUrl, registry.master
      test.equal 2, registry.slaves.length
      test.ok serverUrl2 in registry.slaves
      test.ok serverUrl3 in registry.slaves
      test.done()
  testFileSync: (test)->
    rest.upload serverUrl1,
      ['./test/data/waves.mov'],
      success: (files)=>
        findFile = ->
          contents = fs.readdirSync(File.directory(files[0].id))
          path = File.directory(files[0].id).replace /media/, 'media2'
          console.log "Comparing contents of #{path}"
          fs.readdir path, (slaveContents)=>
            if contents is slaveContents
              test.done()
            else
              console.log "File not found, will try again in 3 secs"
              setTimeout findFile, 3000
        findFile()

  testReset: (test)->
    request.put serverUrl1 + 'registry',
      json: { master: masterUrl }, (err, response, registry)=>
        test.equal response.headers['content-type'], 'application/json'
        test.equal masterUrl, registry.master
        test.equal 0, registry.slaves.length
        server1.kill()
        server2.kill()
        server3.kill()
        test.done()
