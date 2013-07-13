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
            next()
    else next()