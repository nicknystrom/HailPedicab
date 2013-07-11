express  = require('express')
mongoose = require('mongoose')
RedisStore = require('connect-redis')(express)
util = require('util')

mongoose.connect 'mongodb://localhost/acmepedicabs'
mongoose.connection.on 'error', (err) -> console.log 'mongoose error: ', err

app = express()

# serve static files
app.use '/',      express.static('static')

# request body, cookies, sessions, and other housekeeping stuff
app.use express.bodyParser()
app.use express.cookieParser()
app.use express.session(
    store: new RedisStore()
    key: 's'
    secret: '234987dfghjkq2d39807231ojksdfcjhn3w47869324879'
)

# application routes
app.use app.router

# error handlers
if 'development' is app.get('env')
    app.use express.errorHandler(dumpExceptions: true, showStack: true)
if 'production' is app.get('env')
    app.use express.errorHandler()
    
module.exports = require('http').createServer(app)