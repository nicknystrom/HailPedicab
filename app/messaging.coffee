nodemailer = require('nodemailer')
handlebars = require('handlebars')
{union, is_string} = require('./util')

transport = nodemailer.createTransport 'SMTP',
    host: 'smtp.gmail.com'
    secureConnection: true
    port: 465
    auth: { user: 'outbound@belaysoftware.com', pass: 'outbound' }

format_address = (address) ->
    address = [address] unless address instanceof Array
    ((if is_string(a) then a else "#{a.name} <#{a.email ? a.address}>") for a in address).join(',')

EMAIL_DEFAULTS = {
    from: 'AcmePedicabs <support@acmepedicabs.com>'
    subject: 'AcmePedicabs Support'
}

SMS_DEFAULTS = {

}

# notifies a user with a given template and data object. inspects the user's configuration
# to see if they want email or sms for this template
exports.notify = ->

# send an email address, requires a 'from', 'to', 'subject', 'template', 'data'
exports.email = (opts) ->
    opts = union(EMAIL_DEFAULTS, opts)
    if opts.template
        x = opts.template.split('/')
        x.unshift('messages')
        opts.template = handlebars.templates[x.join('/')]
    opts.from = format_address(opts.from)
    opts.to = format_address(opts.to)
    process.nextTick ->
        if opts.template
            opts.html = opts.template(opts.data)
        transport.sendMail opts, (err, status) ->
            console.log "Failed to send email to #{opts.to} with error #{err}." if err

exports.sms = (opts) ->
    opts = union(SMS_DEFAULTS, opts)