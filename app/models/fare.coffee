mongoose = require('mongoose')
moment = require('moment')
{compare_document} = require('../util')

FARE_STATES = [
    'submitted'     # fare submitted
    'expired'       # fare was not dispatched within time limit
    'dispatched'    # driver is on the way
    'active'        # driver is fulfilling ride request
    'complete'      # driver has dropped off FARE_STATES
    'canceled'      # driver did not pick up fare
]

fare = new mongoose.Schema
    state:            { type: String, enum: FARE_STATES, default: 'submitted' }
    name:             { type: String, trim: true }
    location:         [Number]
    driver:           { type: mongoose.Schema.Types.ObjectId, ref: 'driver' }
    estimate:         { type: Date }

    created:          { type: Date, default: -> new Date() }
    dispatched:       { type: Date }
    pickedup:         { type: Date }
    completed:        { type: Date }
    canceled:         { type: Date }

fare.index location: '2dsphere'

fare.virtual('expired').get ->  @state is 'submitted' and moment().subtract(30, 'm') > @created

fare.statics.findAvailable = (driver, next) ->
    @find(state: 'submitted')
        .where('created').gt(moment().subtract(30, 'm'))
        .exec(next)

module.exports = mongoose.model('fare', fare)
module.exports.STATE = FARE_STATES