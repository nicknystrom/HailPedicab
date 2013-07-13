// Generated by CoffeeScript 1.6.3
var Driver, moment;

Driver = require('../models/driver');

moment = require('moment');

module.exports = function(req, res, next) {
  if (req.session && req.session.driver_id) {
    return Driver.findById(req.session.driver_id, function(err, driver) {
      if (err || (driver == null)) {
        req.session.driver_id = null;
        return res.send(500, err || 'Driver not found.');
      }
      req.driver = driver;
      return next();
    });
  } else {
    return next();
  }
};
