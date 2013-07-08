{User, Project, Make} = require('../models')
{_login} = require('../api/login')
{COUNTRIES, STATES, compare_document} = require('../util')

exports.activate = (req, res) ->
    code = req.params.code or req.body.code or req.query.code
    return res.render 'profile/activate' if code is undefined
    User.activate code, (err, u) ->
        return res.send 500, err if err
        return res.render 'profile/activate', {code: code, err: true} unless u
        _login req, res, u, (err) ->
            return res.send 500, err if err
            res.render 'profile/activated'


exports.index = (req, res) ->
    return res.redirect('/') if not req.user
    res.render 'profile/index'