jQuery ($) ->

    navigate = (target) ->
        $('section:visible').hide()
        $(target).show().trigger('navigate')
    $('[data-navigate]').click -> navigate $(this).data('navigate')

    # most requests return a standard driver response envelope
    process = (data, next) ->
        next() unless data
        $('#drivers > header > h1').text data.driver.name
        $('#drivers > header > h2').text data.driver.email
        $('#signout').toggle(true)

    # check current status
    req = $.ajax type: 'get', url: '/api/driver'
    req.done (data) -> process data, (err) -> 
        #
    req.fail (err) -> 
        if err.status is 401
            navigate '#start'

    $('#start').on 'navigate', ->

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
        req.done (data) -> process data, (err, data) -> navigate('#fares')
        req.fail (err) -> alert 'Email or pin is incorrect.'
        false

    $('#register').on('submit', -> false)
                  .h5Validate()
                  .on 'formValidated', (e, data) ->
        return unless data.valid
        req = $.ajax type: 'post', url: '/api/driver', data: {
            name: $('#register-name').val()            
            email: $('#register-email').val()
            pin: $('#register-pin').val()
        }
        req.done (data) -> process data, (err, data) -> navigate('#fares')            #
        req.fail (err) -> alert "Error creating your account:\n#{err.responseText}"
        false
