// Generated by CoffeeScript 1.6.3
jQuery(function($) {
  var address, cancelWatch, circle, geocoder, location, map, navigate, watchCurrentPosition, watchToken;
  watchToken = null;
  watchCurrentPosition = function(enableHighAccuracy, next) {
    if (!navigator.geolocation) {
      return next('nogeo');
    }
    return watchToken = navigator.geolocation.watchPosition(function(data) {
      return next(null, data.coords);
    }, function(e) {
      return next(e.code);
    }, {
      enableHighAccuracy: enableHighAccuracy,
      timeout: 20 * 1024
    });
  };
  cancelWatch = function() {
    if (watchToken) {
      return navigator.geolocation.clearWatch(watchToken);
    }
  };
  navigate = function(target) {
    $('section:visible').hide();
    return $(target).show().trigger('navigate');
  };
  $('[data-navigate]').click(function() {
    return navigate($(this).data('navigate'));
  });
  google.maps.visualRefresh = true;
  map = null;
  circle = null;
  location = null;
  $('#locating').on('navigate', function() {
    var state;
    state = 'locating';
    if (!map) {
      map = new google.maps.Map($('#locating .map')[0], {
        center: new google.maps.LatLng(44.975871, -93.2665563),
        zoom: 12,
        zoomControl: false,
        streetViewControl: false,
        mapTypeControl: false,
        mapTypeId: google.maps.MapTypeId.ROADMAP
      });
      circle = new google.maps.Circle({
        strokeColor: "#bf4433",
        strokeOpacity: 0.8,
        strokeWeight: 2,
        fillColor: "#bf4433",
        fillOpacity: 0.35,
        map: null,
        center: new google.maps.LatLng(0, 0),
        radius: 0
      });
    }
    $('#locating .accuracy.none').show();
    return watchCurrentPosition(true, function(err, coords) {
      var _ref, _ref1;
      if (state === 'locating') {
        if (err === 1) {
          return navigate('#denied-geo');
        }
        if (err === 'nogeo') {
          return navigate('#no-geo');
        }
        if (err) {
          return navigate('#no-gps');
        }
        if (!(location && coords.accuracy > location.accuracy)) {
          circle.setMap(map);
          circle.setCenter(new google.maps.LatLng(coords.latitude, coords.longitude));
          circle.setRadius(coords.accuracy);
          map.setCenter(new google.maps.LatLng(coords.latitude, coords.longitude));
          map.setZoom(14);
          location = coords;
          $('#locating .accuracy:visible').hide();
          if (location.accuracy >= 250) {
            $('#locating .accuracy.none').show();
          }
          if ((125 <= (_ref = location.accuracy) && _ref < 250)) {
            $('#locating .accuracy.low').show();
          }
          if ((75 < (_ref1 = location.accuracy) && _ref1 < 125)) {
            $('#locating .accuracy.medium').show();
          }
          if (location.accuracy <= 150) {
            return navigate('#hail');
          }
        }
      }
      if (state === 'ready') {
        if (coords.accuracy < 50) {
          return location = coords;
        }
      }
      if (state === 'submitted') {
        if (coords.accuracy < 50) {
          return location = coords;
        }
      }
    });
  });
  $('#denied-geo, #no-geo, #no-gps').on('navigate', function() {
    var state;
    cancelWatch();
    return state = 'no-geo';
  });
  geocoder = null;
  address = null;
  $('#hail').on('navigate', function() {
    var state;
    cancelWatch();
    state = 'ready';
    address = null;
    if (!geocoder) {
      geocoder = new google.maps.Geocoder();
    }
    return geocoder.geocode({
      latLng: new google.maps.LatLng(location.latitude, location.longitude)
    }, function(data, status) {
      console.log(status);
      if (address) {
        return;
      }
      if (!data || data.length === 0) {
        return $('#hail .address .value').text("" + location.latitude + ", " + location.longitude);
      }
      address = data[0].formatted_address;
      return $('#hail .address .value').text(address);
    });
  });
  $('#hail button').click(function() {
    var req;
    req = $.ajax({
      type: 'post',
      url: '/api/fare',
      data: {
        name: $('#hail-name').val(),
        long: location.longitude,
        lat: location.latitude
      }
    });
    req.done(function(data) {
      var state;
      console.log(data);
      state = data.state;
      return navigate('#submitted');
    });
    return req.fail(function(err) {
      return alert("Error creating fare:\n" + err.responseText);
    });
  });
  return navigate('#locating');
});
