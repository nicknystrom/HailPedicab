{User} = require('../models')
moment = require('moment')

module.exports = () ->
    (req, res, next) ->

        # authenticate user
        if req.session and req.session.authenticated
            User.findById req.session.user, (err, u) ->
                return res.send 500, err if err
                return res.send 500, 'Unable to find authenticated user.' unless u

                # set the current user for this request
                req.user = u
                res.locals.user = u

                # record user activity, but only once per minute, and only for  non-xhr
                # requests (except for XHR posts, which presumbly represent a user activity)
                if (req.method isnt 'GET' or not req.xhr) and moment().diff(moment(u.last_activity)) > 60000
                    u.last_activity = new Date()

                # issue a save, if its empty mongoose shouldnt do anything
                u.save next
        else
            next()