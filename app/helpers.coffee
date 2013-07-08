util = require('util')
handlebars = require('handlebars')
moment = require('moment')
humanize = require('humanize')
{title, merge, union, shallow, compare_document} = require('./util')

handlebars.registerHelper 'inspect',       (x) -> util.inspect x, false, 3
handlebars.registerHelper 'date',          (date) -> if date? then moment(date).format('L') else ''
handlebars.registerHelper 'time',          (date) -> if date? then moment(date).format('LT') else ''
handlebars.registerHelper 'since',         (date) -> if date? then moment(date).fromNow() else ''
handlebars.registerHelper 'currency',      (number) -> if number? then '$' + humanize.numberFormat(number) else ''
handlebars.registerHelper 'integer',       (number) -> if number? then humanize.numberFormat(number, 0) else ''
handlebars.registerHelper 'yesno',         (bool) -> if bool then 'Yes' else 'No'
handlebars.registerHelper 'titlecase',     (x) -> title x
handlebars.registerHelper 'json',          (x) -> new handlebars.SafeString(JSON.stringify(x))
handlebars.registerHelper 'to_input_name', (x) -> x.replace /[-.]/g, '_'                            # converts typicaly html ids to appropriate input names
handlebars.registerHelper 'with',          (context, options) -> options.fn(context)
handlebars.registerHelper 'percent',       (x) -> if isNaN(x) then '-' else ((x*100).toFixed('2') + '%')

# returns a context variable by name, useful for retrieving form values in input partial
# has smarts to also check the name as to_input_name would have mangled it
handlebars.registerHelper 'get', (x) ->
    a = this[x] ? this[x.replace /[-.]/g, '_']

# usage {{#hash stuff}}<li>{{key}} = {{value}}</li>{{/hash}}
# iterates over key/value pairs in first argument
handlebars.registerHelper 'hash', (hash, options) ->
	return if not hash
	data = shallow this
	(options.fn(merge data, key: key, value: value) for own key, value of hash).join('')
	
# usage: {{helper 'fields/text' a="b" c="d" ... }}
# renders the partial at 'helpers/fields/text' using the hash
# arguments merged into the current context.
handlebars.registerHelper 'helper', (partial, options) ->
    data = union this, options.hash
    path = "helpers/#{partial}"
    partial = handlebars.partials[path]
    if not partial
        throw "No partial found named '#{path}'."
    return new handlebars.SafeString(partial(data))

# {{set 'variable' to=@index}}
handlebars.registerHelper 'set', (left, options) ->
    this[left] = options.hash.to
    ''

# {{#compare a to="b"}}equal{{else}}not equal{{/compare}}
handlebars.registerHelper 'compare', (a, options) -> 
    ix = options.hash?.index
    to = options.hash?.to
    to = to[ix] if ix?
    if a == to then options.fn(this) else options.inverse(this)

# {{#compare_document a to="b"}}equal{{else}}not equal{{/compare}}
handlebars.registerHelper 'compare_document', (a, options) -> 
    ix = options.hash?.index
    to = options.hash?.to
    to = to[ix] if ix?
    if compare_document(a, to) then options.fn(this) else options.inverse(this)

# usage: {{#map a x="1" y="2" z="3"}}
# evaluates 'a' and compares it to the values x, y, or z, rendering the
# matching value. In the example, if 'a' were 'y', the output would be '2'.
handlebars.registerHelper 'map', (a, options) ->
    return val for own key, val of options.hash when key is a

# usage: {{#contains_document ../user.friends needle=_id}}
handlebars.registerHelper 'contains_document', (a, options) ->
    needle = options.hash?.needle
    (return options.fn(this)) for x in a when compare_document(x, needle)
    return options.inverse(this)

# usage: {{#contains ../user.friends needle=_id}}
handlebars.registerHelper 'contains', (a, options) ->
    needle = options.hash?.needle
    (return options.fn(this)) for x in a when x is needle
    return options.inverse(this)
