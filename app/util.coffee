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
