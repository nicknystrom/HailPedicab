mongoose = require('mongoose')
crypto = require('crypto')
uuid = require('node-uuid')
moment = require('moment')
{compare_document} = require('../util')

Bool = require('./types/boolean')

ONLINE_THRESHOLD = 5*60*1000
    
Phone = new mongoose.Schema
    kind:         { type: String, trim: true, default: 'Home' }
    number:       { type: String, trim: true }

user = new mongoose.Schema
    activation_code:  { type: String, default: -> uuid.v4() }
    active:           Bool(default: false)
    first:            { type: String, trim: true }
    middle:           { type: String, trim: true }
    last:             { type: String, trim: true }
    email:            { type: String, trim: true, unique: true, lowercase: true }
    phone:            [Phone]
    role:             { type: String, enum: ['Driver'] }
    
    salt:             { type: String }
    password:         { type: String }
    password_changed: { type: Date }
    password_source:  { type: String }
    password_reset:   {
        pin:          { type: String }
        expires:      { type: Date }
    }

    created:          { type: Date, default: -> new Date() }
    activated:        { type: Date }
    last_login:       { type: Date }
    last_activity:    { type: Date, default: -> new Date() }

user.virtual('name').get ->
    return "#{this.first} #{this.last}" unless this.middle and this.middle.length > 0
    "#{this.first} #{this.middle[0].toUpperCase()} #{this.last}"

user.virtual('online').get -> this.model('user').test_last_activity(this.last_activity)

user.statics.test_last_activity = (last_activity) -> (moment().diff(moment(last_activity))) < ONLINE_THRESHOLD

user.statics.count_online = (next) ->
    horizon = moment().subtract('ms', ONLINE_THRESHOLD)
    this.find(active: true).where('last_activity').gt(horizon).count(next)

# pwd: password to set
# next: (err) ->
user.methods.credential = (pwd, next) ->
    u = this
    crypto.randomBytes 64, (err, buf) ->
        return next(err) if err
        s = buf.toString('hex')
        crypto.pbkdf2 pwd, s, 5000, 512, (err, encoded) ->
            return next(err) if err
            u.salt = s
            u.password = Buffer(encoded, 'binary').toString('hex')
            u.password_changed = new Date()
            return next(null, u)

user.methods.update_profile = (data, next) ->
    this.first                 = data.first       unless data.first is undefined
    this.middle                = data.middle      unless data.middle is undefined
    this.last                  = data.last        unless data.last is undefined
    
    unless data.password is undefined
        this.credential data.password, (err) =>
            return next(err) if err
            this.password_reset.pin = null
            this.password_reset.expires = null
            this.save(next)
    else this.save(next)

# pwd: password to check
# next: (err, result) ->
user.methods.check = (pwd, next) -> 
    u = this
    crypto.pbkdf2 pwd, this.salt, 5000, 512, (err, encoded) ->
        return next(err, false) if err
        return next(null, u.password == Buffer(encoded, 'binary').toString('hex'))

user.statics.activate = (code, next) ->
    this.findOne {activation_code: code}, (err, u) ->
        return next(err) if err
        return next() unless u
        return next(null, u) if u.activated
        u.active = true
        u.activated = new Date()
        u.save (err) ->
            return next(err) if err
            next(null, u)

module.exports = mongoose.model('user', user)
module.exports.ONLINE_THRESHOLD = ONLINE_THRESHOLD