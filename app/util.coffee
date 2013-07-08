fs = require('fs')
path = require('path')
mongoose = require('mongoose')
async = require('async')

# produces a shallow copy of an object
shallow = (a) -> merge {}, a

# merge b into a, overwriting existing keys, returning the modified a
merge = (a, b) ->
    a[key] = val for own key, val of b
    a

# return a new has of b merged into a, without side effects
union = (a, b) -> merge (shallow a), b

exports.shallow = shallow
exports.merge = merge
exports.union = union

exports.is_string = (obj) -> toString.call(obj) is '[object String]'
exports.is_null_or_empty = (str) -> str is undefined or str is null or not exports.is_string(str) or str.length is 0

exports.to_boolean = (obj) ->
    return false if obj is undefined or obj is null or obj is false or obj is "false" or obj is "0" or obj is 0
    true

# returns the document id, whether the document is populated or just a plain id
exports.document_id = (a) ->
    return null unless a
    return a if a.constructor.name is 'ObjectID'
    return mongoose.Types.ObjectId.fromString(a) if a.constructor.name is 'String'
    a._id

# compare two mongoose documents regardless if they are represented as either
# a bare ObjectID or a populated document
exports.compare_document = (a, b) ->
    return (a is b is null) unless a? and b?
    return exports.document_id(a).equals(exports.document_id(b))

# Title Caps
#
# Ported to JavaScript By John Resig - http://ejohn.org/ - 21 May 2008
# Original by John Gruber - http://daringfireball.net/ - 10 May 2008
# License: http://www.opensource.org/licenses/mit-license.php

lower = (word) -> word.toLowerCase()
upper = (word) -> word.substr(0,1).toUpperCase() + word.substr(1)

small = "(a|an|and|as|at|but|by|en|for|if|in|of|on|or|the|to|v[.]?|via|vs[.]?)"
punct = "([!\"#$%&'()*+,./:;<=>?@[\\\\\\]^_`{|}~-]*)"
  
exports.title = (a) ->
    
    parts = []
    split = /[_:.;?!] |(?: |^)["Ò]/g
    index = 0
    
    loop 
        m = split.exec a
        parts.push a.substring(index, if m then m.index else a.length)
            .replace(/\b([A-Za-z][a-z.'Õ]*)\b/g, (all) -> if /[A-Za-z]\.[A-Za-z]/.test(all) then all else upper(all))
            .replace(RegExp("\\b" + small + "\\b", "ig"), lower)
            .replace(RegExp("^" + punct + small + "\\b", "ig"), (all, punct, word) -> return punct + upper(word))
            .replace(RegExp("\\b" + small + punct + "$", "ig"), upper)
        
        index = split.lastIndex
        if m
            parts.push m[0]
        else
            break
    
    parts.join('')
        .replace(/\sV(s?)/ig, " v$1. ")
        .replace(/(['Õ])S\b/ig, "$1s")
        .replace(/\b(AT&T|Q&A)\b/ig, (all) -> all.toUpperCase())

exports.lower = lower
exports.upper = upper

exports.slug = (a) -> 

    # Adapted from https://gist.github.com/3184241
    a.replace(/^\s+|\s+$/g, '').toLowerCase() # trim, lower
     .replace(/[^a-z0-9]/g, '-')              # replace non-alpha-numeric with dash
     .replace(/-+/g, '-')                     # collapse dashes

visitFolder = exports.visitFolder = (folder, filter, visitor, next) ->
    stack = [folder]
    async.whilst(
        -> stack.length > 0
        (next) ->
            i = stack.pop()
            fs.stat i, (err, s) ->
                return next(err) if err
                return next() unless filter(i, s)
                return visitor(i, s, next) unless s.isDirectory()
                fs.readdir i, (err, files) ->
                    return next(err) if err
                    stack.push(path.join(i, f)) for f in files when f[0] isnt '.'
                    next()
        next or (->)
    )

watchFile = exports.watchFile = (i, changed, next) ->
    fs.stat i, (err, s) ->
        return next(err) if err
        mtime = s.mtime.getTime()
        watch = fs.watch i, ->
            
            unless fs.existsSync(i)
                watch.close()
                return changed('deleted', i)

            mtime2 = fs.statSync(i).mtime.getTime()
            if mtime2 > mtime
                mtime = mtime2
                changed('changed', i)

        next() if next
            
watchFolder = exports.watchFolder = (folder, filter, changed, next) ->
    visitFolder folder, filter, ((i, s, next) -> watchFile i, changed, next), next

# inflection is licensed from Shopify under the MIT license:
###

Copyright (C) 2011 by Shopify

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

###

class BatmanInflector
    plural:   (regex, replacement) -> @_plural.unshift [regex, replacement]
    singular: (regex, replacement) -> @_singular.unshift [regex, replacement]
    human:    (regex, replacement) -> @_human.unshift [regex, replacement]
    uncountable: (strings...) -> @_uncountable = @_uncountable.concat(strings.map((x) -> new RegExp("#{x}$", 'i')))
    irregular: (singular, plural) ->
        if singular.charAt(0) == plural.charAt(0)
            @plural new RegExp("(#{singular.charAt(0)})#{singular.slice(1)}$", "i"), "$1" + plural.slice(1)
            @plural new RegExp("(#{singular.charAt(0)})#{plural.slice(1)}$", "i"), "$1" + plural.slice(1)
            @singular new RegExp("(#{plural.charAt(0)})#{plural.slice(1)}$", "i"), "$1" + singular.slice(1)
        else
            @plural new RegExp("#{singular}$", 'i'), plural
            @plural new RegExp("#{plural}$", 'i'), plural
            @singular new RegExp("#{plural}$", 'i'), singular

    constructor: ->
        @_plural = []
        @_singular = []
        @_uncountable = []
        @_human = []

    ordinalize: (number) ->
        absNumber = Math.abs(parseInt(number))
        if absNumber % 100 in [11..13]
            number + "th"
        else
            switch absNumber % 10
                when 1
                    number + "st"
                when 2
                    number + "nd"
                when 3
                    number + "rd"
                else
                    number + "th"

    pluralize: (word) ->
        for uncountableRegex in @_uncountable
            return word if uncountableRegex.test(word)
        for [regex, replace_string] in @_plural
            return word.replace(regex, replace_string) if regex.test(word)
        word

    singularize: (word) ->
        for uncountableRegex in @_uncountable
            return word if uncountableRegex.test(word)
        for [regex, replace_string] in @_singular
            return word.replace(regex, replace_string)  if regex.test(word)
        word

    humanize: (word) ->
        for [regex, replace_string] in @_human
            return word.replace(regex, replace_string) if regex.test(word)
        return word


camelize_rx = /(?:^|_|\-)(.)/g
capitalize_rx = /(^|\s)([a-z])/g
underscore_rx1 = /([A-Z]+)([A-Z][a-z])/g
underscore_rx2 = /([a-z\d])([A-Z])/g
humanize_rx1 = /_id$/
humanize_rx2 = /_|-/g
humanize_rx3 = /^\w/g

Batman = {}
Batman.helpers =
    ordinalize: -> Batman.helpers.inflector.ordinalize.apply Batman.helpers.inflector, arguments
    singularize: -> Batman.helpers.inflector.singularize.apply Batman.helpers.inflector, arguments
    pluralize: (count, singular, plural, includeCount = true) ->
        if arguments.length < 2
            Batman.helpers.inflector.pluralize count
        else
            result = if +count is 1 then singular else (plural || Batman.helpers.inflector.pluralize(singular))
            if includeCount
                result = "#{count || 0} " + result
            result

    camelize: (string, firstLetterLower) ->
        string = string.replace camelize_rx, (str, p1) -> p1.toUpperCase()
        if firstLetterLower then string.substr(0,1).toLowerCase() + string.substr(1) else string

    underscore: (string) ->
        string.replace(underscore_rx1, '$1_$2')
              .replace(underscore_rx2, '$1_$2')
              .replace('-', '_').toLowerCase()

    capitalize: (string) -> string.replace capitalize_rx, (m,p1,p2) -> p1 + p2.toUpperCase()

    trim: (string) -> if string then string.trim() else ""

    interpolate: (stringOrObject, keys) ->
        if typeof stringOrObject is 'object'
            string = stringOrObject[keys.count]
            unless string
                string = stringOrObject['other']
        else
            string = stringOrObject

        for key, value of keys
            string = string.replace(new RegExp("%\\{#{key}\\}", "g"), value)
        string

    humanize: (string) ->
        string = Batman.helpers.underscore(string)
        string = Batman.helpers.inflector.humanize(string)
        string.replace(humanize_rx1, '')
              .replace(humanize_rx2, ' ')
              .replace(humanize_rx3, (match) -> match.toUpperCase())

Inflector = new BatmanInflector
Batman.helpers.inflector = Inflector

Inflector.plural(/$/, 's')
Inflector.plural(/s$/i, 's')
Inflector.plural(/(ax|test)is$/i, '$1es')
Inflector.plural(/(octop|vir)us$/i, '$1i')
Inflector.plural(/(octop|vir)i$/i, '$1i')
Inflector.plural(/(alias|status)$/i, '$1es')
Inflector.plural(/(bu)s$/i, '$1ses')
Inflector.plural(/(buffal|tomat)o$/i, '$1oes')
Inflector.plural(/([ti])um$/i, '$1a')
Inflector.plural(/([ti])a$/i, '$1a')
Inflector.plural(/sis$/i, 'ses')
Inflector.plural(/(?:([^f])fe|([lr])f)$/i, '$1$2ves')
Inflector.plural(/(hive)$/i, '$1s')
Inflector.plural(/([^aeiouy]|qu)y$/i, '$1ies')
Inflector.plural(/(x|ch|ss|sh)$/i, '$1es')
Inflector.plural(/(matr|vert|ind)(?:ix|ex)$/i, '$1ices')
Inflector.plural(/([m|l])ouse$/i, '$1ice')
Inflector.plural(/([m|l])ice$/i, '$1ice')
Inflector.plural(/^(ox)$/i, '$1en')
Inflector.plural(/^(oxen)$/i, '$1')
Inflector.plural(/(quiz)$/i, '$1zes')

Inflector.singular(/s$/i, '')
Inflector.singular(/(n)ews$/i, '$1ews')
Inflector.singular(/([ti])a$/i, '$1um')
Inflector.singular(/((a)naly|(b)a|(d)iagno|(p)arenthe|(p)rogno|(s)ynop|(t)he)ses$/i, '$1$2sis')
Inflector.singular(/(^analy)ses$/i, '$1sis')
Inflector.singular(/([^f])ves$/i, '$1fe')
Inflector.singular(/(hive)s$/i, '$1')
Inflector.singular(/(tive)s$/i, '$1')
Inflector.singular(/([lr])ves$/i, '$1f')
Inflector.singular(/([^aeiouy]|qu)ies$/i, '$1y')
Inflector.singular(/(s)eries$/i, '$1eries')
Inflector.singular(/(m)ovies$/i, '$1ovie')
Inflector.singular(/(x|ch|ss|sh)es$/i, '$1')
Inflector.singular(/([m|l])ice$/i, '$1ouse')
Inflector.singular(/(bus)es$/i, '$1')
Inflector.singular(/(o)es$/i, '$1')
Inflector.singular(/(shoe)s$/i, '$1')
Inflector.singular(/(cris|ax|test)es$/i, '$1is')
Inflector.singular(/(octop|vir)i$/i, '$1us')
Inflector.singular(/(alias|status)es$/i, '$1')
Inflector.singular(/^(ox)en/i, '$1')
Inflector.singular(/(vert|ind)ices$/i, '$1ex')
Inflector.singular(/(matr)ices$/i, '$1ix')
Inflector.singular(/(quiz)zes$/i, '$1')
Inflector.singular(/(database)s$/i, '$1')

Inflector.irregular('person', 'people')
Inflector.irregular('man', 'men')
Inflector.irregular('child', 'children')
Inflector.irregular('sex', 'sexes')
Inflector.irregular('move', 'moves')
Inflector.irregular('cow', 'kine')
Inflector.irregular('zombie', 'zombies')

Inflector.uncountable('equipment', 'information', 'rice', 'money', 'species', 'series', 'fish', 'sheep', 'jeans')

exports.plural = -> Batman.helpers.inflector.pluralize.apply Batman.helpers.inflector, arguments

exports.COUNTRIES =
    'us': 'United States'
    'ca': 'Canada'
    'gb': 'United Kingdom'
    'ax': 'Aland Islands'
    'af': 'Afghanistan'
    'al': 'Albania'
    'dz': 'Algeria'
    'as': 'American Samoa'
    'ad': 'Andorra'
    'ao': 'Angola'
    'ai': 'Anguilla'
    'aq': 'Antarctica'
    'ag': 'Antigua and Barbuda'
    'ar': 'Argentina'
    'am': 'Armenia'
    'aw': 'Aruba'
    'au': 'Australia'
    'at': 'Austria'
    'az': 'Azerbaijan'
    'bs': 'Bahamas'
    'bh': 'Bahrain'
    'bd': 'Bangladesh'
    'bb': 'Barbados'
    'by': 'Belarus'
    'be': 'Belgium'
    'bz': 'Belize'
    'bj': 'Benin'
    'bm': 'Bermuda'
    'bt': 'Bhutan'
    'bo': 'Bolivia'
    'ba': 'Bosnia and Herzegovina'
    'bw': 'Botswana'
    'bv': 'Bouvet Island'
    'br': 'Brazil'
    'io': 'British Indian Ocean Territory'
    'bn': 'Brunei Darussalam'
    'bg': 'Bulgaria'
    'bf': 'Burkina Faso'
    'bi': 'Burundi'
    'kh': 'Cambodia'
    'cm': 'Cameroon'
    'cv': 'Cape Verde'
    'bq': 'Caribbean Netherlands '
    'ky': 'Cayman Islands'
    'cf': 'Central African Republic'
    'td': 'Chad'
    'cl': 'Chile'
    'cn': 'China'
    'cx': 'Christmas Island'
    'cc': 'Cocos (Keeling) Islands'
    'co': 'Colombia'
    'km': 'Comoros'
    'cg': 'Congo'
    'cd': 'Congo, Democratic Republic of'
    'ck': 'Cook Islands'
    'cr': 'Costa Rica'
    'hr': 'Croatia'
    'cu': 'Cuba'
    'cw': 'CuraÁao'
    'ci': 'CÙte d\'Ivoire'
    'cy': 'Cyprus'
    'cz': 'Czech Republic'
    'dk': 'Denmark'
    'dj': 'Djibouti'
    'dm': 'Dominica'
    'do': 'Dominican Republic'
    'ec': 'Ecuador'
    'eg': 'Egypt'
    'sv': 'El Salvador'
    'gq': 'Equatorial Guinea'
    'er': 'Eritrea'
    'ee': 'Estonia'
    'et': 'Ethiopia'
    'fk': 'Falkland Islands'
    'fo': 'Faroe Islands'
    'fj': 'Fiji'
    'fi': 'Finland'
    'fr': 'France'
    'gf': 'French Guiana'
    'pf': 'French Polynesia'
    'tf': 'French Southern Territories'
    'ga': 'Gabon'
    'gm': 'Gambia'
    'ge': 'Georgia'
    'de': 'Germany'
    'gh': 'Ghana'
    'gi': 'Gibraltar'
    'gr': 'Greece'
    'gl': 'Greenland'
    'gd': 'Grenada'
    'gp': 'Guadeloupe'
    'gu': 'Guam'
    'gt': 'Guatemala'
    'gg': 'Guernsey'
    'gn': 'Guinea'
    'gw': 'Guinea-Bissau'
    'gy': 'Guyana'
    'ht': 'Haiti'
    'hm': 'Heard and McDonald Islands'
    'hn': 'Honduras'
    'hk': 'Hong Kong'
    'hu': 'Hungary'
    'is': 'Iceland'
    'in': 'India'
    'id': 'Indonesia'
    'ir': 'Iran'
    'iq': 'Iraq'
    'ie': 'Ireland'
    'im': 'Isle of Man'
    'il': 'Israel'
    'it': 'Italy'
    'jm': 'Jamaica'
    'jp': 'Japan'
    'je': 'Jersey'
    'jo': 'Jordan'
    'kz': 'Kazakhstan'
    'ke': 'Kenya'
    'ki': 'Kiribati'
    'kw': 'Kuwait'
    'kg': 'Kyrgyzstan'
    'la': 'Lao People\'s Democratic Republic'
    'lv': 'Latvia'
    'lb': 'Lebanon'
    'ls': 'Lesotho'
    'lr': 'Liberia'
    'ly': 'Libya'
    'li': 'Liechtenstein'
    'lt': 'Lithuania'
    'lu': 'Luxembourg'
    'mo': 'Macau'
    'mk': 'Macedonia'
    'mg': 'Madagascar'
    'mw': 'Malawi'
    'my': 'Malaysia'
    'mv': 'Maldives'
    'ml': 'Mali'
    'mt': 'Malta'
    'mh': 'Marshall Islands'
    'mq': 'Martinique'
    'mr': 'Mauritania'
    'mu': 'Mauritius'
    'yt': 'Mayotte'
    'mx': 'Mexico'
    'fm': 'Micronesia, Federated States of'
    'md': 'Moldova'
    'mc': 'Monaco'
    'mn': 'Mongolia'
    'me': 'Montenegro'
    'ms': 'Montserrat'
    'ma': 'Morocco'
    'mz': 'Mozambique'
    'mm': 'Myanmar'
    'na': 'Namibia'
    'nr': 'Nauru'
    'np': 'Nepal'
    'nc': 'New Caledonia'
    'nz': 'New Zealand'
    'ni': 'Nicaragua'
    'ne': 'Niger'
    'ng': 'Nigeria'
    'nu': 'Niue'
    'nf': 'Norfolk Island'
    'kp': 'North Korea'
    'mp': 'Northern Mariana Islands'
    'no': 'Norway'
    'om': 'Oman'
    'pk': 'Pakistan'
    'pw': 'Palau'
    'ps': 'Palestinian Territory, Occupied'
    'pa': 'Panama'
    'pg': 'Papua New Guinea'
    'py': 'Paraguay'
    'pe': 'Peru'
    'ph': 'Philippines'
    'pn': 'Pitcairn'
    'pl': 'Poland'
    'pt': 'Portugal'
    'pr': 'Puerto Rico'
    'qa': 'Qatar'
    're': 'Reunion'
    'ro': 'Romania'
    'ru': 'Russian Federation'
    'rw': 'Rwanda'
    'bl': 'Saint BarthÈlemy'
    'sh': 'Saint Helena'
    'kn': 'Saint Kitts and Nevis'
    'lc': 'Saint Lucia'
    'vc': 'Saint Vincent and the Grenadines'
    'mf': 'Saint-Martin (France)'
    'sx': 'Saint-Martin (Pays-Bas)'
    'ws': 'Samoa'
    'sm': 'San Marino'
    'st': 'Sao Tome and Principe'
    'sa': 'Saudi Arabia'
    'sn': 'Senegal'
    'rs': 'Serbia'
    'sc': 'Seychelles'
    'sl': 'Sierra Leone'
    'sg': 'Singapore'
    'sk': 'Slovakia (Slovak Republic)'
    'si': 'Slovenia'
    'sb': 'Solomon Islands'
    'so': 'Somalia'
    'za': 'South Africa'
    'gs': 'South Georgia and the South Sandwich Islands'
    'kr': 'South Korea'
    'ss': 'South Sudan'
    'es': 'Spain'
    'lk': 'Sri Lanka'
    'pm': 'St. Pierre and Miquelon'
    'sd': 'Sudan'
    'sr': 'Suriname'
    'sj': 'Svalbard and Jan Mayen Islands'
    'sz': 'Swaziland'
    'se': 'Sweden'
    'ch': 'Switzerland'
    'sy': 'Syria'
    'tw': 'Taiwan'
    'tj': 'Tajikistan'
    'tz': 'Tanzania'
    'th': 'Thailand'
    'nl': 'The Netherlands'
    'tl': 'Timor-Leste'
    'tg': 'Togo'
    'tk': 'Tokelau'
    'to': 'Tonga'
    'tt': 'Trinidad and Tobago'
    'tn': 'Tunisia'
    'tr': 'Turkey'
    'tm': 'Turkmenistan'
    'tc': 'Turks and Caicos Islands'
    'tv': 'Tuvalu'
    'ug': 'Uganda'
    'ua': 'Ukraine'
    'ae': 'United Arab Emirates'
    'um': 'United States Minor Outlying Islands'
    'uy': 'Uruguay'
    'uz': 'Uzbekistan'
    'vu': 'Vanuatu'
    'va': 'Vatican'
    've': 'Venezuela'
    'vn': 'Vietnam'
    'vg': 'Virgin Islands (British)'
    'vi': 'Virgin Islands (U.S.)'
    'wf': 'Wallis and Futuna Islands'
    'eh': 'Western Sahara'
    'ye': 'Yemen'
    'zm': 'Zambia'
    'zw': 'Zimbabwe'

exports.STATES =
    'us': {
        'al': 'Alabama'
        'ak': 'Alaska'
        'as': 'American Samoa'
        'az': 'Arizona'
        'ar': 'Arkansas'
        'ca': 'California'
        'co': 'Colorado'
        'ct': 'Connecticut'
        'de': 'Delaware'
        'dc': 'District Of Columbia'
        'fm': 'Federated States Of Micronesia'
        'fl': 'Florida'
        'ga': 'Georgia'
        'gu': 'Guam'
        'hi': 'Hawaii'
        'id': 'Idaho'
        'il': 'Illinois'
        'in': 'Indiana'
        'ia': 'Iowa'
        'ks': 'Kansas'
        'ky': 'Kentucky'
        'la': 'Louisiana'
        'me': 'Maine'
        'mh': 'Marshall Islands'
        'md': 'Maryland'
        'ma': 'Massachusetts'
        'mi': 'Michigan'
        'mn': 'Minnesota'
        'ms': 'Mississippi'
        'mo': 'Missouri'
        'mt': 'Montana'
        'ne': 'Nebraska'
        'nv': 'Nevada'
        'nh': 'New Hampshire'
        'nj': 'New Jersey'
        'nm': 'New Mexico'
        'ny': 'New York'
        'nc': 'North Carolina'
        'nd': 'North Dakota'
        'mp': 'Northern Mariana Islands'
        'oh': 'Ohio'
        'ok': 'Oklahoma'
        'or': 'Oregon'
        'pw': 'Palau'
        'pa': 'Pennsylvania'
        'pr': 'Puerto Rico'
        'ri': 'Rhode Island'
        'sc': 'South Carolina'
        'sd': 'South Dakota'
        'tn': 'Tennessee'
        'tx': 'Texas'
        'ut': 'Utah'
        'vt': 'Vermont'
        'vi': 'Virgin Islands'
        'va': 'Virginia'
        'wa': 'Washington'
        'wv': 'West Virginia'
        'wi': 'Wisconsin'
        'wy': 'Wyoming'
    }
    'ca': {
        'ab': 'Alberta'
        'bc': 'British Columbia'
        'mb': 'Manitoba'
        'nb': 'New Brunswick'
        'nf': 'Newfoundland'
        'nt': 'Northwest Territories'
        'ns': 'Nova Scotia'
        'on': 'Ontario'
        'pe': 'Prince Edward Island'
        'qc': 'Quebec'
        'sk': 'Saskatchewan'
        'yt': 'Yukon'
    }