messaging = require('../messaging')

exports.contact = (req, res) ->

    data = {
        name: req.body.name
        email: req.body.email
        message: req.body.message
    }
    messaging.email 
        template: 'contact/notification'
        data:     data
        from:     { name: data.name, address: data.email }
        to:       [
            { name: 'Acme Pedicabs Support', address: 'support@acmepedicabs.com' }
        ]
        subject:  'Acme Pedicabs Hail a Cab Contact Form'

    res.send 200, {result: true}