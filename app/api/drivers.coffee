
Driver = require('../models/driver')
Fare = require('../models/fare')
async = require('async')

module.exports = (app) ->

    lookup = (req, res, next) ->
        if req.session and req.session.driver_id
            Driver.findById(req.session.driver_id).populate('fare').exec (err, driver) ->
                if err or not driver?
                    req.session.driver_id = null
                    return res.send 500, (err or 'Driver not found.')
                req.driver = driver
                req.dispatch = driver.fare
                next()
        else next()

    serializeFare = (f) -> 
        return undefined unless f
        data = {
            id: f.id
            state: f.state
            name: f.name
            long: 0
            lat: 0
            created: f.created
        }
        data.long = f.location[0] if f.location and f.location.length > 0
        data.lat = f.location[1] if f.location and f.location.length > 1
        data            

    report = (driver, dispatch, next) ->
        Fare.findAvailable driver, (err, fares) ->
            return next(err) if err
            next null, {
                fare: serializeFare(dispatch)
                fares: (serializeFare(f) for f in fares)
                driver: {
                    name: driver.name
                    email: driver.email
                    mobile: driver.mobile
                    state: driver.state
                }
            }

    # login
    app.post '/api/session', (req, res) ->
        Driver.findOne(
            email: req.body.email,
            pin: req.body.pin
        ).populate('fare').exec (err, driver) ->
            return res.send 500, err if err
            return res.send 401 unless driver
            req.driver = driver
            req.dispatch = driver.fare
            req.session.driver_id = driver.id
            req.driver.state = 'ready' unless req.dispatch
            req.driver.state = 'dispatched' if req.dispatch
            req.driver.last_activity = new Date()
            req.driver.save (err) ->
                return res.send 500, err if err
                report req.driver, req.dispatch, (err, data) ->
                    return res.send 500, err if err
                    res.send 200, data

    # logout
    app.delete '/api/session', lookup, (req, res) ->
        return res.send 200, 'No session' unless req.session
        req.session.driver_id = null
        async.series [

            (next) ->
                return next() unless req.dispatch
                req.dispatch.state = 'canceled'
                req.dispatch.canceled = new Date()
                req.dispatch.save next

            (next) ->
                return next() unless req.driver
                req.driver.fare = null
                req.driver.state = 'offline'
                req.driver.save next

            (next) ->
                res.send 200, 'Goodbye'
                next()

        ], (err) -> res.send 500, err if err

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
                    mobile: req.body.mobile
                    pin: req.body.pin
                    location: [0,0]
                    last_activity: new Date()
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
                report driver, null, (err, data) ->
                    return next(err) if err
                    res.send 200, data
                    next()

        ], (err) -> res.send 500, err if err

    # update profile
    app.put  '/api/driver', lookup, (req, res) ->
        return res.send 401 unless req.driver
        req.driver.name = req.body.name
        req.driver.mobile = req.body.mobile
        req.driver.save (err) ->
            return res.send 500, err if err
            report req.driver, req.dispatch, (err, data) ->
                return res.send 500, err if err
                res.send 200, data

    # return current available fares, driver status, and current fare status
    # meant to be polleds
    app.get  '/api/driver', lookup, (req, res) ->
        return res.send 401 unless req.driver
        report req.driver, req.dispatch, (err, data) ->
            return res.send 500, err if err
            res.send 200, data

    # driver claims a fare
    app.post '/api/dispatch/:fare', lookup, (req, res) ->
        return res.send 401 unless req.driver
        async.waterfall [

            # find the requested fare
            (next) ->
                Fare.findById req.params.fare, (err, fare) ->
                    return next(err) if err
                    return res.send 400, "Fare cannot be dispatched at this time (current state is #{fare.state})." if fare.state isnt 'submitted'
                    next(null, fare)

            # what about our driver's current fare?
            (fare, next) ->
                return next(null, fare) unless req.dispatch
                req.dispatch.state = 'canceled'
                req.dispatch.canceled = new Date()
                req.dispatch.save (err) ->
                    return next(err) if err
                    req.driver.fare = null
                    req.dispatch = null
                    next(null, fare)

            # update the driver
            (fare, next) ->
                req.dispatch = fare
                req.driver.fare = fare
                req.driver.state = 'dispatched'
                req.driver.save (err) ->
                    return next(err) if err
                    next()

            # update the fare
            (next) ->
                req.dispatch.driver = req.driver
                req.dispatch.state = 'dispatched'
                req.dispatch.estimate = req.body.estimate
                req.dispatch.dispatched = new Date()
                req.dispatch.save (err) ->
                    return next(err) if err
                    next()

            (next) -> 
                report req.driver, req.dispatch, (err, data) ->
                    return next(err) if err
                    res.send 200, data
                    next()

        ], (err) -> res.send 500, err if err
        
    # driver indicates the fair is picked up
    app.put '/api/dispatch/:fare', lookup, (req, res) ->
        return res.send 401 unless req.driver
        return res.send 400 unless req.dispatch and req.driver.state is 'dispatched'
        return res.send 403 unless req.dispatch.id is req.params.fare
        async.series [

            (next) ->
                req.dispatch.state = 'complete'
                req.dispatch.pickedup = new Date()
                req.dispatch.completed = new Date()
                req.dispatch.save(next)
            
            (next) ->
                req.dispatch = null
                req.driver.state = 'ready'
                req.driver.fare = null
                req.driver.save(next)

            (next) -> 
                report req.driver, req.dispatch, (err, data) ->
                    return next(err) if err
                    res.send 200, data
                    next()

        ], (err) -> res.send 500, err if err

    # clears the driver's dispatched fare.. typically if the user canceled
    # the request, this returns them to main screen
    app.delete '/api/dispatch', lookup, (req, res) ->
        return res.send 401 unless req.driver
        req.dispatch = null
        req.driver.fare = null
        req.driver.state = 'ready'
        req.driver.save (err) ->
            return res.send 500, err if err
            report req.driver, req.dispatch, (err, data) ->
                return res.send 500, err if err
                res.send 200, data

    # driver indicates they arent going to pickup the fare after all
    app.delete '/api/dispatch/:fare', lookup, (req, res) ->
        return res.send 401 unless req.driver
        return res.send 400 unless req.dispatch and req.driver.state is 'dispatched'
        return res.send 403 unless req.dispatch.id is req.params.fare
        async.series [

            (next) ->
                req.dispatch.state = 'canceled'
                req.dispatch.canceled = new Date()
                req.dispatch.save(next)

            (next) ->
                req.dispatch = null
                req.driver.fare = null
                req.driver.state = 'ready'
                req.driver.save(next)

            (next) -> 
                report req.driver, req.dispatch, (err, data) ->
                    return next(err) if err
                    res.send 200, data
                    next()

        ], (err) -> res.send 500, err if err