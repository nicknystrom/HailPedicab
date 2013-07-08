moment = require('moment')
{User} = require('../models')
messaging = require('../messaging')

_login = exports._login = (req, res, user, next) ->
    req.session.regenerate (err) ->
        return next(err) if err
        req.user = user
        res.locals.user = user
        req.session.authenticated = true
        req.session.user = user.id
        next()

exports.login = (req, res) ->
    User.findOne {active: true, email: req.body.email}, (err, u) ->
        return res.send 500, err if err
        return res.send 500 unless u
        u.check req.body.password, (err, result) -> 
            return res.send 500 if err or not result
            u.last_login = new Date()
            u.last_activity = new Date()
            u.save (err) ->
                return res.send 500, {result: false, err: err} if err
                _login req, res, u, (err) ->
                    return res.send 500, {result: false, err: err} if err
                    res.send u
                
exports.logout = (req, res) ->
    req.session.destroy (err) ->
        return res.send 500, err if err
        res.send {result: true}

exports.validate_email = (req, res) ->
    email = req.params.email or req.body.email or req.query.email
    User.count {email: email}, (err, count) ->
        return res.send 500, err if err
        return res.json 'Email address already in use' if count > 0
        res.json true

send_reset = (req, res, u) ->    
    u.password_reset.pin = [
        Math.floor(Math.random()*10),
        Math.floor(Math.random()*10),
        Math.floor(Math.random()*10),
        Math.floor(Math.random()*10),
    ].join('')
    u.password_reset.expires = moment().add('h', 1).toDate()
    u.save (err) ->
        return res.send 500, err if err
        messaging.email 
            template: 'account/reset'
            data:     { u: u }
            to:       { name: u.name, address: u.email }
            subject:  'Acme Pedicabs Password Reset'
        res.send 200, { expires: u.password_reset.expires }

complete_reset = (req, res, u, pin, pwd) ->
    return res.send 404 unless u.password_reset.pin is pin and new Date <= u.password_reset.expires
    u.credential pwd, (err) ->
        return res.send 500, err if err
        u.password_reset.pin = null
        u.password_reset.expires = null
        u.save (err) ->
            return res.send 500, err if err
            return res.send 200

exports.reset = (req, res) ->
    email = req.body.email
    pin = req.body.pin
    pwd = req.body.password
    User.findOne {email: email}, (err, u) ->
        return res.send 500, err if err
        return res.send 404 unless u
        if pin and pwd then complete_reset(req, res, u, pin, pwd) else send_reset(req, res, u)

exports.signup = (req, res) ->
    return res.send 500, {result: false, err: 'Password is required, minimum of six characters.'} if not req.body.password or req.body.password.length < 6
    User.count {email: req.params.email}, (err, count) ->
        return res.send 500, {result: false, err: 'Email address already in use.'} if err or count > 0
        u = new User(
            role:          'Driver'
            active:        false
            first:         req.body.first
            middle:        req.body.middle
            last:          req.body.last
            email:         req.body.email)
        
        u.phone.push {
            kind:      'Mobile'
            number:    req.body.phone
        } unless req.body.phone is undefined

        u.credential req.body.password, (err) ->
            u.save (err) ->
                return res.send 500, err if err
                messaging.email {
                    template: 'account/activate'
                    data:     { u: u }
                    to:       { name: u.name, address: u.email }
                    subject:  'Acme Pedicabs Activation'
                }
                res.send u
                    