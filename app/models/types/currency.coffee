{union} = require('../../util')

defaults =
  type: Number
  min: 0
  set: (v) ->
    if (typeof v == 'string' and v.length > 1 and v[0] == '$')
      return parseFloat(v.substr(1).replace(/,/g, ''))
    else
      return v

module.exports = (opts) -> union(defaults, opts)
