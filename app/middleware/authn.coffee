Driver = require('../models/driver')
moment = require('moment')

module.exports = (req, res, next) ->

    # lookup authenticated driver
    if req.session and req.session.driver_id
        Driver.findById req.session.driver_id, (err, driver) ->
            if err or not driver?
                req.session.driver_id = null
                return res.send 500, (err or 'Driver not found.')
            req.driver = driver

            # record user activity, but only once per minute, and only for  non-xhr
            # requests (except for XHR posts, which presumbly represent a user activity)
            if not req.driver.last_activity? or moment().diff(moment(req.driver.last_activity)) > 1000 * 60 * 20
                req.driver.last_activity = new Date()
                req.driver.save next
            else
                next()

    else next()