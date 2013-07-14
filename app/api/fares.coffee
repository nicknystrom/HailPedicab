Fare = require('../models/fare')
async = require('async')

module.exports = (app) ->

    lookup = (req, res, next) -> 
        if req.session and req.session.fare_id
            Fare.findById(req.session.fare_id).populate('driver').exec (err, fare) ->
                if err or not fare?
                    req.session.fare_id = null
                    return res.send 500, (err or 'Fare not found.')
                req.fare = fare
                return next() unless fare.expired
                fare.state = 'expired'
                fare.canceled = new Date()
                fare.save next
        else next()

    report = (fare) ->
        {
            state: fare.state,
            name: fare.name,
            long: fare.location[0]
            lat: fare.location[1]
        }

    # post new fare
    app.post '/api/fare', lookup, (req, res) ->

        async.waterfall [

            # look for existing fare, cancel it
            (next) ->
                return next() unless req.fare
                req.fare.state = 'canceled'
                req.fare.canceled = new Date()
                req.fare.save (err) -> 
                    return next(err) if err
                    req.fare = null
                    req.session.fare_id = null
                    next()

            # create new fare
            (next) ->
                fare = new Fare(
                    name: req.body.name
                    location: [req.body.long, req.body.lat]
                )
                fare.save (err) ->
                    return next(err) if err
                    next(null, fare)

            # save to session
            (fare, next) ->
                req.fare = fare
                req.session.fare_id = fare.id
                next(null, fare)

            # send to client
            (fare, next) ->
                res.send 200, report(fare)
                next()

        ], (err) -> res.send 500, err if err

    # polling rider status request
    app.get '/api/fare', lookup, (req, res) ->
        return res.send 401 unless req.fare
        data = {
            state: req.fare.state
            estimate: req.fare.estimate
        }
        data.driver = req.fare.driver.name if req.fare.driver
        res.send 200, data
        
    # rider is canceling request
    app.delete '/api/fare', lookup, (req, res) ->
        return res.send 401 unless req.fare
        async.series [

            (next) ->
                req.fare.state = 'canceled'
                req.fare.canceled = new Date()
                req.fare.save next

            (next) ->
                req.session.fare_id = null
                req.fare = null
                res.send 200, 'Fare request canceled'

        ], (err) -> res.send 500, errr if err

    # rider acknowledges request is complete
    app.put '/api/fare', lookup, (req, res) ->
        return res.send 401 unless req.fare
        return res.send 400 unless req.fare.state in ['complete', 'canceled', 'expired']
        req.session.fare_id = null
        req.fare = null
        res.send 200, 'Thanks'