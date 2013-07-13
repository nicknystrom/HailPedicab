
Driver = require('../models/driver')
Fare = require('../models/fare')
async = require('async')

module.exports = (app) ->

    lookup = (req, res, next) ->
        if req.session and req.session.driver_id
            Driver.findById req.session.driver_id, (err, driver) ->
                if err or not driver?
                    req.session.driver_id = null
                    return res.send 500, (err or 'Driver not found.')
                req.driver = driver
                next()
        else next()

    report = (driver, res) ->
        {
            driver: {
                name: driver.name
                email: driver.email
            }
        }

    # login
    app.post '/api/session', (req, res) ->
        Driver.findOne {
            email: req.body.email,
            pin: req.body.pin
        }, (err, driver) ->
            return res.send 500, err if err
            return res.send 401 unless driver
            req.driver = driver
            req.session.driver_id = driver.id
            res.send 200, report(driver)

    # logout
    app.delete '/api/session', (req, res) ->
        return res.send 200, 'No session' unless req.session
        req.session.driver_id = null
        res.send 200, 'Goodbye'

    # register
    app.post '/api/driver', (req, res) ->
        async.waterfall [

            # check for existing email
            (next) -> 
                Driver.findOne email: req.body.email, (err, driver) ->
                    return next(err) if err
                    return next('Email already in use') if driver
                    next()

            # create record
            (next) ->
                driver = new Driver(
                    email: req.body.email
                    name: req.body.name
                    pin: req.body.pin
                )
                driver.save (err) ->
                    return next(err) if err
                    next(null, driver)

            # save in session
            (driver, next) -> 
                req.session.driver_id = driver.id
                req.driver = driver
                next(null, driver)

            # send standard driver response
            (driver, next) ->
                res.send 200, report(driver)
                next()

        ], (err) -> res.send 500, err if err

    # update profile
    app.put  '/api/driver', lookup, (req, res) ->
        return res.send 401 unless req.driver

    # return current available fares, driver status, and current fare status
    # meant to be polleds
    app.get  '/api/driver', lookup, (req, res) ->
        return res.send 401 unless req.driver
        res.send 200, report(req.driver)
