mongoose = require('mongoose')
moment = require('moment')
{compare_document} = require('../util')

DRIVER_STATES = [
    'ready'        # driver is ready to accept fare request
    'dispatched'   # driver is transiting to fare
    'active'       # driver is delivering fare
    'offline'      # driver is not on shift
]

driver = new mongoose.Schema
    state:            { type: String, enum: DRIVER_STATES}
    name:             { type: String, trim: true }
    email:            { type: String, trim: true }
    location:         [Number]
    created:          { type: Date, default: -> new Date() }

driver.index location: '2dsphere'

module.exports = mongoose.model('driver', driver)