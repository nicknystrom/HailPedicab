{User} = require('../models')
{compare_document} = require('../util')
    
exports.update = (req, res) ->
    return res.send 403 unless req.user
    User.findById req.user._id, (err, u) ->
        return res.send 500, err if err
        u.update_profile req.body, (err) ->
            return res.send 500, err if err
            res.send u