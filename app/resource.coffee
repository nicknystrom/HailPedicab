mongoose = require('mongoose')
util = require('util')
 
# options:
# 'populate': array of populate names used in get queries, not used in list for performance reasons
# 'transform': callback that can be used to make modifications to models prior to serialization
# 'query': callback with signature (req, query) that can be used to build filters into the 
#          list query. can inspect the request object to determine passwed form or querystring values,
#          can also apply static filters like {deleted: false)}

exports.register = (app, schema, options) ->

    plural = (options['root'] or '') + '/api/' + schema.modelName
    single = plural + '/:id'

    withModel = (req, res, next) ->
        q = schema.findById req.params.id
        for a in (options.populate or [])
            q.populate(a)
        q.exec (err, item) ->
            return res.send 500, err if err
            return res.send 404 unless item
            req.model = item
            next()

    # updates a model instance with a plain values object. extracts values
    # from the object by first iterating over the defined 'paths' in the model's
    # schema and then checking for them in the values object. this prevents
    # malicious data in the values object from damaging the model instance
    updateModel = (model, values, next) ->
        for path, type of model.schema.paths when path not in ['_id', 'id']
            n = values
            n = n?[part] for part in path.split '.'
            model.set(path, n) if n isnt undefined
        if options.update then options.update(model, values, next) else next(null, model)

    # convert to a plain object, remove anything named 'password', allow
    # user specified transforms
    transformModel = (model, next) -> 
        model = model.toObject() if model.toObject
        delete model['password']
        delete model['salt']
        if options.transform then options.transform(model, next) else next(null, model)

    # perform basic skip, limit, and sort functions, allow a user callback
    # to refine the query based on any filters that might be sent
    transformQuery = (req, query, spec) ->
        spec.s = req.query.s or req.body.s # order
        spec.i = Number(req.query.i or req.body.i or 0) # index
        spec.n = Number(req.query.n or req.body.n or 1000) # count
        query.sort(spec.s) if spec.s
        query.limit(if spec.n isnt NaN then Math.min(spec.n, 1000) else 1000) # hard limit this to 1000
        query.skip(spec.i) if spec.i isnt NaN
        query.lean(true)
        query = options.query(req, query, spec) if options.query
        return query

    # get
    app.get single, withModel, (req, res) ->
        transformModel req.model, (model) -> res.send(model)

    # update
    app.put single, withModel, (req, res) -> 
        updateModel req.model, req.body, (err, model) ->
            return res.send 500, err if err
            model.save (err) ->
                return res.send 500, err if err
                transformModel req.model, (err, model) ->
                    return res.send 500, err if err
                    res.send(model)

    # delete
    app.del single, withModel, (req, res) ->
        req.model.remove (err) ->
            return res.send 500, err if err
            res.send {}

    transform_pump = (source, destination, next) ->
        return next(null, destination) if (source.length == destination.length)
        transformModel source[destination.length], (err, model) ->
            return next(err) if err
            destination.push(model)
            process.nextTick -> transform_pump(source, destination, next)
    
    # list
    app.get plural, (req, res) ->
        spec = {}
        q = schema.find()
        q = options.query(req, q, spec) if options.query
        q.count (err, count) ->
            return res.send 500, err if err
            spec.count = count
            q = transformQuery(req, schema.find(), spec)
            q.exec (err, list) ->
                return res.send 500, err if err
                transform_pump list, [], (err, transformed) ->
                    return res.send 500, err if err
                    spec.items = transformed
                    res.send 200, spec
    
    # create 
    app.post plural, (req, res) ->
        req.model = new schema()
        updateModel req.model, req.body, (err, model) ->
            return res.send 500, err if err
            model.save (err) ->
                return res.send 500, err if err
                transformModel req.model, (err, model) ->
                    return res.send 500, err if err
                    res.send(model)