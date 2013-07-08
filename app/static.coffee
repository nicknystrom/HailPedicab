async = require('async')
fs = require('fs')
path = require('path')
coffee = require('coffee-script')
{compile_js, compile_less} = require('./views')
{visitFolder, watchFile, watchFolder} = require('./util')

lessFiles = exports.lessFiles = {
    '/static/styles/site.css': 'public/styles/site.less'
    # '/static/styles/admin.css': 'public/styles/admin.less'
}

jsFiles = exports.jsFiles = {
    '/static/js/master.js': [
        'public/vendor/jquery-2.0.3.js'
        'node_modules/moment/moment.js'
        'public/js/master.coffee'
    ]
}

js = (files, options) ->

    cache = null
    (compile = ->
        compile_js files, options, (err, data) ->
            return console.log("Error compiling static javascript, #{err}") if err
            cache = data
    )()

    # watch for changes
    if options?.watch
        async.each files, (i, next) ->
            next()
            watchFile i, (change, i) ->
                console.log "Detected change in #{i}, recompiling..."
                compile() unless change is 'deleted'
                
                
    (req, res) ->
        res.type 'js'
        res.set 'Content-Encoding', 'gzip' if typeof cache isnt 'string'
        res.send cache

less = (file, options) ->

    cache = null
    (compile = ->
        compile_less file, options, (err, data) ->
            return console.log("Error compiling static css, #{file}: #{err}") if err
            cache = data
    )()

    # watch for changes
    if options?.watch
        watchFolder path.dirname(file),
            (i, s) -> s.isDirectory() or (s.size > 0 and path.extname(i) is '.less')
            (event, i) -> 
                console.log "Detected change in #{i}, recompiling #{file}..."
                compile()
            
    (req, res) ->
        res.type 'css'
        res.set 'Content-Encoding', 'gzip' if typeof cache isnt 'string'
        res.send cache

pathToStatic = (url) -> path.normalize(path.join(process.cwd(), '.build', url))

makeFolders = (folder, next) ->
    async.reduce(
        x for x in (folder.split(path.sep)) when x,
        '/',
        (memo, part, next) ->
            memo = path.join(memo, part)
            fs.exists memo, (exists) ->
                return next(null, memo) if exists
                fs.mkdir memo, (err) -> next(null, memo)
        (err) -> next(err)
    )

exports.build = (next) ->

    async.parallel [

        # build static css files
        (next) -> 
            async.eachSeries (x for x, y of lessFiles),
                (url, next) ->
                    input = lessFiles[url]
                    output = pathToStatic(url)
                    console.log "Compiling #{input} to #{output}"
                    compile_less input, { minify: true, compress: true }, (err, data) ->
                        return next(err) if err
                        makeFolders path.dirname(output), (err) ->
                            return next(err) if err
                            fs.writeFile output, data, (err) ->
                                next(err)
                (err) ->
                    console.log "Error compiling less files: #{err}" if err
                    next(err)

        # build static js files
        (next) ->
            async.eachSeries (x for x, y of jsFiles),
                (url, next) ->
                    input = jsFiles[url]
                    output = pathToStatic(url)
                    console.log "Compiling #{input.length} files to #{output}"
                    compile_js input, { minify: true, compress: true }, (err, data) ->
                        return next(err) if err
                        makeFolders path.dirname(output), (err) ->
                            return next(err) if err
                            fs.writeFile output, data, (err) ->
                                next(err)
                (err) ->
                    console.log "Error compiling js files: #{err}" if err
                    next(err)

        # build application coffee files
        (next) ->
            visitFolder 'app',
                (f, s) -> s.isDirectory() or (s.size > 0 and path.extname(f) is '.coffee')
                (f, s, next) -> 
                    output = path.join(process.cwd(), '.build', path.dirname(f), path.basename(f, '.coffee') + '.js')
                    fs.readFile f, 'utf8', (err, data) ->
                        return next(err) if err
                        data = coffee.compile(data)
                        makeFolders path.dirname(output), (err) ->
                            return next(err) if err
                            fs.writeFile output, data, next
                next
        ],
        (err) -> next(err)

serve = (app, url, type) ->
    cache = null
    fs.readFile pathToStatic(url), (err, data) -> cache = data
    app.get url, (req, res) ->
        res.type type
        res.set 'Content-Encoding', 'gzip'
        res.send cache

exports.apply = (app) ->

    # build options for css and javascript compilers
    if app.get('env') is 'production'

        # serve from static files
        serve(app, url, 'css') for url, file of lessFiles
        serve(app, url, 'js') for url, file of jsFiles
        return
        
    # service content dynamically compiled
    opts =
        watch:    true
        minify:   false
        compress: false
    app.get(url, less(file, opts)) for url, file of lessFiles
    app.get(url, js(files, opts)) for url, files of jsFiles