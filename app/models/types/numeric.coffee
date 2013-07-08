{union} = require('../../util')

defaults =
  type: Number
  set: (v) ->
    if (typeof v == 'string' and v.length > 1)
      return parseFloat(v.replace(/,/g, ''))
    else
      return v

module.exports = (opts) -> union(defaults, opts)
