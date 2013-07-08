models = require('../models')
resource = require('../resource')
moment = require('moment')

exports.resources = (app) ->
    resource.register app, models.User,
        root: '/admin'
        query: (req, query, spec) ->
            spec.q = (req.body.q or req.query.q)
            if spec.q
                rx = new RegExp(spec.q, 'i')
                query.or [
                    {first: rx}
                    {last: rx}
                    {email: rx}
                ]
            query
        transform: (user, next) ->
            user.online = models.User.test_last_activity(user.last_activity)
            next(null, user)
        update: (model, values, next) ->
            return next(null, model) unless values.password
            model.credential values.password, next

now = (req, res, next) ->
    res.locals.now = new Date()
    next()

online_users_middleware = (req, res, next) ->   
    models.User.count_online (err, users_online) ->
        return res.send 500, err if err
        res.locals.users_online = users_online
        next()

exports.middleware = [now, online_users_middleware]

exports.index = (req, res) -> res.render 'admin/index'
exports.users = (req, res) -> res.render 'admin/users'

exports.profile = (req, res) ->
    models.User.findById req.params.id, (err, user) ->
        return res.send 500, err if err
        return res.send 404 unless user
        user.update_profile req.body, (err) ->
            return res.send 500, err if err
            return res.send 200, user

exports.impersonate = (req, res) ->
    models.User.findById req.params.id, (err, user) ->
        return res.send 500, err if err
        return res.send 404 unless user
        req.session.authenticated = true
        req.session.user = user._id
        res.redirect '/'

_sorts = {
    'first':      (u) -> u.user.first
    'last':       (u) -> u.user.last
    'company':    (u) -> u.user.company
    'last_login': (u) -> u.last_login
    'completed':  (u) -> u.completed
    'expires':    (u) -> u.expires 
    'grade':      (u) -> u.grade
    'issued':     (u) -> u.user.protected.cert_issued
}
