jQuery ($) ->

    watchToken = null
    watchCurrentPosition = (enableHighAccuracy, next) ->
        return next('nogeo') unless navigator.geolocation
        watchToken = navigator.geolocation.watchPosition(
            (data) -> next(null, data.coords)
            (e) -> next(e.code)
            {
                enableHighAccuracy: enableHighAccuracy,
                timeout: 20*1024
            })
    cancelWatch = ->
        navigator.geolocation.clearWatch(watchToken) if watchToken

    navigate = (target) ->
        $('section:visible').hide()
        $(target).show().trigger('navigate')
    $('[data-navigate]').click -> navigate $(this).data('navigate')

    google.maps.visualRefresh = true
    map = null
    circle = null
    location = null
    state = null
    $('#locating').on 'navigate', ->
        state = 'locating'

        # setup google map
        unless map
            map = new google.maps.Map $('#locating .map')[0], {
                center: new google.maps.LatLng(44.975871, -93.2665563)
                zoom: 12
                zoomControl: false
                streetViewControl: false
                mapTypeControl: false
                mapTypeId: google.maps.MapTypeId.ROADMAP  
            }
            circle = new google.maps.Circle(
                strokeColor: "#bf4433"
                strokeOpacity: 0.8
                strokeWeight: 2
                fillColor: "#bf4433"
                fillOpacity: 0.35
                map: null
                center: new google.maps.LatLng(0, 0)
                radius: 0
            )

        # begin monitoring position
        $('#locating .accuracy.none').show()
        watchCurrentPosition true, (err, coords) ->
            if state is 'locating'

                # wait for a location within 75 meters
                return navigate '#denied-geo' if err is 1
                return navigate '#no-geo' if err is 'nogeo'
                return navigate '#no-gps' if err
                unless location and coords.accuracy > location.accuracy

                    # update circle
                    circle.setMap map
                    circle.setCenter new google.maps.LatLng(coords.latitude, coords.longitude)
                    circle.setRadius coords.accuracy
                    map.setCenter new google.maps.LatLng(coords.latitude, coords.longitude)
                    map.setZoom 14

                    location = coords 
                    $('#locating .accuracy:visible').hide()
                    $('#locating .accuracy.none').show() if location.accuracy >= 250
                    $('#locating .accuracy.low').show() if 125 <= location.accuracy < 250
                    $('#locating .accuracy.medium').show() if 75 < location.accuracy < 125
                    return navigate '#hail' if location.accuracy <= 150
                        
            if state is 'ready'

                # update the location as long as its under 50 meters
                return location = coords if coords.accuracy < 50

            if state is 'submitted'

                # if the a new, relatively accurate location is received, make sure we havent
                # moved
                return location = coords if coords.accuracy < 50

    $('#denied-geo, #no-geo, #no-gps').on 'navigate', ->
        cancelWatch()
        state = 'no-geo'

    geocoder = null
    address = null
    $('#hail').on 'navigate', ->

        cancelWatch()
        state = 'ready'

        # attempt to geocode the location
        address = null
        geocoder = new google.maps.Geocoder() unless geocoder
        geocoder.geocode { latLng: new google.maps.LatLng(location.latitude, location.longitude) },
            (data, status) ->
                return if address
                return $('#hail .address .value').text("#{location.latitude}, #{location.longitude}") if not data or data.length is 0
                address = data[0].formatted_address                    
                $('#hail .address .value').text(address)

    $('#hail button').click ->
        req = $.ajax(type: 'post', url: '/api/fare', data: {
            name: $('#hail-name').val()
            long: location.longitude
            lat: location.latitude
        })
        req.done (data) ->
            process (data), -> setTimeout(refresh, REFRESH_INTERVAL)
            navigate('#submitted')
        req.fail (err) -> alert "Error creating fare:\n#{err.responseText}"

    # most requests return a standard driver response envelope
    process = (data, next) ->
        return next('no-data') unless data

        state = data.state

        navigate '#canceled' if data.state is 'canceled'
        navigate '#submitted' if data.state is 'submitted'
        navigate '#dispatched' if data.state is 'dispatched'
        navigate '#complete' if data.state is 'complete'
        navigate '#expired' if data.state is 'expired'

        $('#fares > section .driver').text(data.driver)
        $('#fares > section .estimate').text(moment(data.estimate).fromNow())

        next()

    REFRESH_INTERVAL = 30*1000
    refresh = (next) ->

        # check current status
        req = $.ajax type: 'get', url: '/api/fare'
        req.done (data) -> process data, ->
            next() if next
            setTimeout(refresh, REFRESH_INTERVAL)    
        req.fail (err) -> 
            navigate '#locating' if err.status is 401

    $('#fares > section button.cancel').on 'click', ->
        text = 'Are you sure you want to cancel your request?'
        text = 'Your driver is already on the way! ' + text if state is 'dispatched'
        if confirm(text)
            req = $.ajax(
                type: 'delete'
                url: '/api/fare'
            )
            req.done (data) -> process data, -> navigate '#locating'
            req.fail (err) -> alert(err.responseText)

    $('#fares > section button.done').on 'click', ->
        req = $.ajax(
            type: 'put'
            url: '/api/fare'
        )
        req.done (data) -> process data, -> navigate '#locating'
        req.fail (err) -> alert(err.responseText)


    refresh()