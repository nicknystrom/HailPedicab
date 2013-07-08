fs = require('fs')
path = require('path')
http = require('http')
spawn = require('child_process').spawn
handlebars = require('handlebars')
util = require('util')
mime = require('mime')
zlib = require('zlib')
{watchFolder, watchFile, visitFolder} = require('./app/util')

option '-f', '--force', 'Foricibly run the start-db or stop-db command, ignoring the lock file.'
option '-w', '--watch', 'Watches directories for changed files (applies to /src and up server only).'
option '-n', '--number [WORKERS]', 'Number of work processes to spawn (applies to up server only)'
option '-p', '--port [PORT]', 'Port number to listen on.'
option '-i', '--ip [IP]', 'IP address used to test location service.'
option '-e', '--email [EMAIL]', 'Email address of user to change.'

defaults =
    watch: false
    number: 1
    port: 3042
    ip: '76.17.246.240'

mergeDefaultsInto = (opts) -> 
    (opts[key] = val if typeof opts[key] is 'undefined') for key, val of defaults
    opts

copyFile = (from, to, next) ->
    fileA = fs.createReadStream(from)
    fileB = fs.createWriteStream(to)
    fileA.pipe(fileB)
    fileA.once('end', next) if next

appendFile = (from, to, next) ->
    fileA = fs.createReadStream(from)
    fileB = fs.createWriteStream(to, 'flags': 'a')
    fileB.pipe(fileA)    
    fileA.once('end', next) if next

task 'build',
    'Builds javascript and css static artifacts from coffeescript/less resources',
    (opts) ->
        mergeDefaultsInto opts
        console.log "Building static js and css artifacts:"
        require('./app/static').build (err) -> process.exit(if err then 1 else 0)

task 'run',
    'Execute the server using the \'up\' load balancer.',
    (opts) ->
        mergeDefaultsInto opts
        console.log "Launching server on port #{opts.port} with #{opts.number} workers..."
        if not opts.watch and opts.number is 1
            app = require('./app')
            app.listen(opts.port)
        else
            server = http.Server().listen(opts.port)
            up = require('up')(
                server, 
                __dirname,
                workerPingInterval: '1s'
                numWorkers: opts.number
                workerTimeout: '2s'
            )
            if opts.watch
                console.log "  .. Watching for changes"
                watchFolder './app',
                    (-> true),
                    (ev, fn) ->
                        console.log "  .. Saw change in #{fn}, reloading server."
                        up.reload()
                    () ->