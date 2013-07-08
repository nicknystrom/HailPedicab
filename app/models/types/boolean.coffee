{union} = require('../../util')

defaults =
  type: Boolean
  set: (v) ->
    return false unless v?
    if typeof v is 'string'
        return v in ['True', 'true', 'Yes', 'yes', '1', 'T', 't', 'Y', 'y']
    return Boolean(v)

module.exports = (opts) -> union(defaults, opts)
