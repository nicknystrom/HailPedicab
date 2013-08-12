jQuery ($) ->

    navigate = (target, data) ->
        $('section:visible').hide()
        $(target).show().trigger('navigate', data)
    $('[data-navigate]').click -> navigate $(this).data('navigate')

    # most requests return a standard driver response envelope
    process = (data, next) ->
        return next('no-data') unless data

        # update driver header
        $('#drivers > header > h1').text data.driver.name
        $('#drivers > header > h2').text data.driver.email
        $('#drivers > header > h3').text data.driver.mobile
        $('#drivers > header .btn').toggle(true)

        # update profile text fields
        $('#profile-name').val(data.driver.name)
        $('#profile-mobile').val(data.driver.mobile)

        # update fare list
        $('#available > ul').empty()
        for f in data.fares
            $('#available > ul').append(
                $("<li data-id=\"#{f.id}\">
                    <span class=\"name\"><span class=\"value\">#{f.name}</span></span>
                    <span class=\"distance\"><span class=\"value\">#{3} miles</span></span>
                    <span class=\"since\"><span class=\"value\">#{moment(f.created).fromNow()}</span></span>
                </li>").data('fare', f)
            )

        next()

        # if the driver assigned to a fare?
        # note: comes after next(), this overrides other stuff
        if data.fare
            return navigate '#canceled' if data.fare.state is 'canceled'
            $('#fare').toggleClass('dispatched', true)
            navigate '#fare', data.fare

    REFRESH_INTERVAL = 20*1000
    refresh = (next) ->

        # check current status
        req = $.ajax type: 'get', url: '/api/driver'
        req.done (data) -> process data, ->
            next() if next
            setTimeout(refresh, REFRESH_INTERVAL)    
        req.fail (err) -> 
            if err.status is 401
                navigate '#start'

    # start the refresh cycle
    refresh -> navigate '#available'

    $('#start').on 'navigate', ->
        $('#drivers > header .btn').toggle(false)

    $('#signout').click ->
        req = $.ajax type: 'delete', url: '/api/session'
        req.done (data) -> 
            alert 'Thanks for driving!'
            window.location.reload()
        req.fail (err) -> alert 'Whoops, failed to signout.'
        false

    $('#login').on('submit', -> false)
               .h5Validate()
               .on 'formValidated', (e, data) ->
        return unless data.valid
        req = $.ajax type: 'post', url: '/api/session', data: {
            name: $('#login-name').val()            
            email: $('#login-email').val()
        }
        req.done (data) -> process data, ->
            navigate('#available')
            setTimeout(refresh, REFRESH_INTERVAL)
        req.fail (err) -> alert 'Email or pin is incorrect.'
        false

    $('#register').on('submit', -> false)
                  .h5Validate()
                  .on 'formValidated', (e, data) ->
        return unless data.valid
        req = $.ajax type: 'post', url: '/api/driver', data: {
            name: $('#register-name').val()            
            email: $('#register-email').val()
            mobile: $('#register-mobile').val()
            pin: $('#register-pin').val()
        }
        req.done (data) -> process data, ->
            navigate('#available')
            setTimeout(refresh, REFRESH_INTERVAL)
        req.fail (err) -> alert "Error creating your account:\n#{err.responseText}"
        false

    $('#profile-form').on('submit', -> false)
                 .h5Validate()
                 .on 'formValidated', (e, data) ->
        return unless data.valid
        req = $.ajax type: 'put', url: '/api/driver', data: {
            name: $('#profile-name').val()            
            mobile: $('#profile-mobile').val()
        }
        req.done (data) -> process data, ->
            navigate('#available')
            setTimeout(refresh, REFRESH_INTERVAL)
        req.fail (err) -> alert "Error updating your account:\n#{err.responseText}"
        false                    

    $('#available').on 'click', 'li', (e) ->
        $('#fare').toggleClass('dispatched', false)
        navigate '#fare', $(e.currentTarget).data('fare')

    fare = null
    map = null
    marker = null
    $('#fare').on 'navigate', (e, f) ->

        # if we're already assigned this fare, nothing has changed
        # on the map, so exit now
        return if fare is f

        fare = f
        $('#fare .name').text(f.name)
        unless map
            map = new google.maps.Map $('#fare .map')[0], {
                center: new google.maps.LatLng(f.lat, f.long)
                zoom: 14
                zoomControl: false
                streetViewControl: false
                mapTypeControl: false
                mapTypeId: google.maps.MapTypeId.ROADMAP  
            }
            marker = new google.maps.Marker(
                map: map
                position: new google.maps.LatLng(f.lat, f.long)
                title: f.name
            )
        else
            marker.setPosition(new google.maps.LatLng(f.lat, f.long))
            marker.setTitle(f.name)
            map.setCenter(new google.maps.LatLng(f.lat, f.long))
            map.setZoom(14)

    $('#fare button.dispatch').on 'click', ->
        req = $.ajax {
            type: 'post'
            url: '/api/dispatch/' + fare.id
            data: {
                estimate: moment().add(Number($(this).data('estimate')), 'm').toDate()
            }
        }
        req.done (data) -> process data, (err) ->
        req.fail (err) -> alert(err.responseText)

    $('#fare button.pickup').on 'click', ->
        req = $.ajax(
            type: 'put'
            url: '/api/dispatch/' + fare.id
        )
        req.done (data) -> process data, (err) -> navigate '#available'
        req.fail (err) -> alert(err.responseText)

    $('#fare button.cancel').on 'click', ->
        if confirm('Are you sure you can\'t or won\'t find this fare?')
            req = $.ajax(
                type: 'delete'
                url: '/api/dispatch/' + fare.id
            )
            req.done (data) -> process data, (err) -> navigate '#available'
            req.fail (err) -> alert(err.responseText)

    $('#canceled button.done').on 'click', ->
        req = $.ajax(
            type: 'delete'
            url: '/api/dispatch'
        )
        req.done (data) -> process data, (err) -> navigate '#available'
        req.fail (err) -> alert(err.responseText)        