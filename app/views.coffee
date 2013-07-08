fs = require('fs')
path = require('path')
handlebars = require('handlebars')
util = require('util')
less = require('less')
zlib = require('zlib')
coffee = require('coffee-script')
uglify = require('uglify-js')
async = require('async')
{WritableStreamBuffer} = require('stream-buffers')
{visitFolder, watchFile, watchFolder} = require('./util')

templates = handlebars.templates = handlebars.templates or {}
partials = handlebars.partials;

exports.compile_views = (folder, options) ->
    
    compile = (i) ->
        content = fs.readFileSync(i, 'utf8')
        fn = null
        try
            fn = handlebars.compile(content, {})
        catch ex
            return console.log "Failed to compile view #{i}: \n#{ex}"
        name = path.basename(i, '.handlebars')
        prefix = path.relative(folder, path.dirname(i))
        prefix = prefix + '/' if prefix.length > 0
        if name[0] is '_'
            partials[prefix + name[1..]] = fn
        else
            templates[prefix + name] = fn

    visitFolder folder,
        (i, s) -> s.isDirectory() or (s.size > 0 and path.extname(i) is '.handlebars')
        (i, s, next) ->
            compile(i)
            next()
            if options?.watch
                watchFile i,
                    (op) ->
                        return console.log "View file #{i} has been deleted, restart application to apply this change." if op is 'deleted'
                        console.log "Detected change in #{i}, recompiling..."
                        compile(i)

compress = (content, next) ->
    buffer = new WritableStreamBuffer
    gzip = zlib.createGzip(level: 9)
    gzip.on 'data', (chunk) -> buffer.write(chunk)
    gzip.on 'end', -> next(buffer)
    gzip.end content

compile_js = exports.compile_js = (files, options, next) ->

    buffer = ''
    async.each files,
        (i, next) ->
            fs.readFile i, 'utf8', (err, data) ->
                next(err) if err
                buffer += '\n' + data if path.extname(i) is '.js'
                buffer += coffee.compile(data, filename: i) if path.extname(i) is '.coffee'
                next()
        (err) ->
            return next(err) if err

            # minify
            if options?.minify
                result = uglify.minify buffer, fromString: true
                buffer = result.code

            # compress
            next(null, buffer) unless options?.compress 
            compress buffer, (data) -> next(null, data.getContents())



compile_less = exports.compile_less = (file, options, next) ->
    
    parser = new less.Parser(
        paths: [path.dirname(file)]
        filename: file
    )
    fs.readFile file, 'utf8', (err, data) ->
        return next(err) if err
        parser.parse data, (err, tree) ->
            next(err) if err
            out = tree.toCSS(
                yuicompress: optiosn?.minify
            )
            return next(null, out) unless options?.compress
            compress out, (data) -> next(null, data.getContents())

