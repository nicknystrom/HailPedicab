express = require('express')

admins = 
    nick: { role: 'admin', password: 'battleship' }
    anthony: { role: 'admin', password: 'battleship' }

unauthorized = (res, realm) ->
    res.statusCode = 401
    res.setHeader 'WWW-Authenticate', "Basic realm=\"#{realm}\"'"
    res.end 'Unauthorized'

module.exports = (realm) ->
    realm ?= 'Authorization Required'
    (req, res, next) ->

        return next() if req.admin_user
        return unauthorized(res, realm) unless req.headers.authorization

        parts = req.headers.authorization.split(' ')
        return next(400) unless parts.length is 2

        credentials = new Buffer(parts[1], 'base64').toString()
        index = credentials.indexOf(':')
        return next(400) if parts[0] isnt 'Basic' or index < 0
        
        user = credentials.slice(0, index)
        pass = credentials.slice(index + 1)

        a = admins[user]
        return unauthorized(res, realm) unless a and a.password is pass
        req.admin_user = a
        next()
