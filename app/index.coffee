express  = require('express')
mongoose = require('mongoose')
RedisStore = require('connect-redis')(express)
handlebars = require('handlebars')
moment = require('moment')
util = require('util')
models = require('./models')
path = require('path')
{title, merge, union, shallow} = require('./util')

# install precompiled handlebars views
require('./views').compile_views('./views', watch: false)

# install handlebar helpers
require('./helpers')
    
# express 3 handlebars engine
hbs = (filename, options, next) ->

    # figure out the compiled view name.. pretty much just the path without .handlebars
    rel = path.relative(options.settings.views, filename)
    parts = (p for p in path.dirname(rel).split(path.sep) when p isnt '.')
    view = path.basename(filename, path.extname(filename))
    name = if parts.length > 0 then parts.join('/') + '/' + view else view

    # load and render the template
    template = handlebars.templates[name]
    if not template
        throw "No view at path '#{name}'"
    result = template(options)

    # now look for a layout
    layout = options.layout
    if layout is undefined and not options.xhr
        for i in [parts.length-1..0]
            lp = parts[0..i].concat('layout').join('/')
            if handlebars.templates[lp]
                layout = lp
        if not layout
            if handlebars.templates['layout']
                layout = 'layout'

    # if a layout name given, render it with the inner template result assigned to 'body'
    if layout and layout.length > 0
        template = handlebars.templates[layout]
        if not template
            throw "No layout found at path '#{layout}'"
        options.body = result
        result = template(options)

    next(null, result)

mongoose.connect 'mongodb://localhost/acmepedicabs'

mongoose.connection.on 'error', (err) ->
    console.log 'mongoose error: ', err

app = express()

# view engine configuration
app.enable('trust proxy')
app.set 'views', 'views'
app.set 'view engine', 'handlebars'
app.engine 'handlebars', hbs

# serve static files
app.set 'static_path', '/static'
app.use '/static/img',      express.static('public/img')
app.use '/static/font', express.static('public/lib/font-awesome/font')

# request body, cookies, sessions, and other housekeeping stuff
app.use express.bodyParser()
app.use express.methodOverride()
app.use express.cookieParser()
app.use express.session(
    store: new RedisStore()
    key: 's'
    secret: 'lawevu3o489adscfkuiya39843743iauyahd'
)

# application routes
app.use require('./middleware/layout')()
app.use require('./middleware/authn')()     # read authenticate data from request (either session or possibly oauth tokns, etc)
app.use '/admin', require('./middleware/admin')('Acme Pedicabs')
app.use app.router

# server compiled less and js content
require('./static').apply(app)

# error handlers
if 'development' is app.get('env')
    app.use express.errorHandler(dumpExceptions: true, showStack: true)
if 'production' is app.get('env')
    app.use express.errorHandler()

app.locals.page_title = 'Acme Pedicabs'
    
require('./routes').register app
require('./controllers/admin').resources app

module.exports = require('http').createServer(app)