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
app.use '/api', express.bodyParser()
app.use '/api', express.cookieParser()
app.use '/api', express.session(
    store: new RedisStore()
    key: 's'
    secret: '234987dfghjkq2d39807231ojksdfcjhn3w47869324879'
)
app.use '/api', require('./middleware/authn')

require('./api/drivers')(app)
require('./api/fares')(app)

# application routes
app.use app.router

# error handlers
if 'development' is app.get('env')
    app.use express.errorHandler(dumpExceptions: true, showStack: true)
if 'production' is app.get('env')
    app.use express.errorHandler()
    
module.exports = require('http').createServer(app)