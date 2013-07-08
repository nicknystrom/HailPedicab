mongoose = require('mongoose')
moment = require('moment')
{compare_document} = require('../util')

FARE_STATES = [
    'pending'       # fare submitted
    'expired'       # fare was not dispatched within time limit
    'dispatched'    # driver is on the way
    'active'        # driver is fulfilling ride request
    'complete'      # driver has dropped off FARE_STATES
    'canceled'      # driver did not pick up fare
]

fare = new mongoose.Schema
    state:            { type: String, enum: FARE_STATES}
    name:             { type: String, trim: true }
    location:         [Number]

    created:          { type: Date, default: -> new Date() }
    dispatched:       { type: Date }
    pickedup:         { type: Date }
    completed:        { type: Date }
    canceled:         { type: Date }