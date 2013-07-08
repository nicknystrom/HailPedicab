module.exports = ->
    (req, res, next) ->
        res.locals.xhr = req.xhr
        res.locals.layout = null if req.xhr
        next()