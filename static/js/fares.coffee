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
        navigator.geolocation.cancelWatch(watchToken) if watchToken

    navigate = (target) ->
        $('section:visible').hide()
        $(target).show().trigger('navigate')
    $('[data-navigate]').click -> navigate $(this).data('navigate')
    
    $('#locating').on 'navigate', ->
        location = null
        state = 'locating'
        $('#locating .accuracy.none').show()
        watchCurrentPosition true, (err, coords) ->
            if state is 'locating'

                # wait for a location within 50 meters
                return navigate '#denied-geo' if err is 1
                return navigate '#no-geo' if err is 'nogeo'
                return navigate '#no-gps' if err
                unless location and coords.accuracy > location.accuracy
                    location = coords 
                    $('#locating .accuracy:visible').hide()
                    $('#locating .accuracy.none').show() if location.accuracy >= 250
                    $('#locating .accuracy.low').show() if 125 <= location.accuracy < 250
                    $('#locating .accuracy.medium').show() if 75 < location.accuracy < 125
                    return navigate '#hail' if location.accuracy <= 75
                        
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

    $('#hail').on 'navigate', ->
        state = 'ready'

    # start by finding our location
    navigate '#locating'
