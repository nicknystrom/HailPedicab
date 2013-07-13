// Generated by CoffeeScript 1.6.3
var Driver, Fare, async;

Driver = require('../models/driver');

Fare = require('../models/fare');

async = require('async');

module.exports = function(app) {
  var lookup, report;
  lookup = function(req, res, next) {
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
  report = function(driver, res) {
    return {
      driver: {
        name: driver.name,
        email: driver.email
      }
    };
  };
  app.post('/api/session', function(req, res) {
    return Driver.findOne({
      email: req.body.email,
      pin: req.body.pin
    }, function(err, driver) {
      if (err) {
        return res.send(500, err);
      }
      if (!driver) {
        return res.send(401);
      }
      req.driver = driver;
      req.session.driver_id = driver.id;
      return res.send(200, report(driver));
    });
  });
  app["delete"]('/api/session', function(req, res) {
    if (!req.session) {
      return res.send(200, 'No session');
    }
    req.session.driver_id = null;
    return res.send(200, 'Goodbye');
  });
  app.post('/api/driver', function(req, res) {
    return async.waterfall([
      function(next) {
        return Driver.findOne({
          email: req.body.email
        }, function(err, driver) {
          if (err) {
            return next(err);
          }
          if (driver) {
            return next('Email already in use');
          }
          return next();
        });
      }, function(next) {
        var driver;
        driver = new Driver({
          email: req.body.email,
          name: req.body.name,
          pin: req.body.pin
        });
        return driver.save(function(err) {
          if (err) {
            return next(err);
          }
          return next(null, driver);
        });
      }, function(driver, next) {
        req.session.driver_id = driver.id;
        req.driver = driver;
        return next(null, driver);
      }, function(driver, next) {
        res.send(200, report(driver));
        return next();
      }
    ], function(err) {
      if (err) {
        return res.send(500, err);
      }
    });
  });
  app.put('/api/driver', lookup, function(req, res) {
    if (!req.driver) {
      return res.send(401);
    }
  });
  return app.get('/api/driver', lookup, function(req, res) {
    if (!req.driver) {
      return res.send(401);
    }
    return res.send(200, report(req.driver));
  });
};
