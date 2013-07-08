routes =
    admin:     require('./controllers/admin')
    home:      require('./controllers/home')
    profile:   require('./controllers/profile')
      
api =    
    login:     require('./api/login')
    public:    require('./api/public')
    profile:   require('./api/profile')
    

exports.register = (app) ->

    # public pages
    app.get  '/',                          routes.home.index
    app.post '/',                          routes.home.index
    app.get  '/faq',                       routes.home.faq 
    app.get  '/guide',                     routes.home.guide 
    app.get  '/reset',                     routes.home.reset
    app.get  '/contact',                   routes.home.contact
    app.all  '/activate',                  routes.profile.activate
    app.get  '/activate/:code',            routes.profile.activate
    
    # user pages
    app.get  '/profile',                   routes.profile.index

    # contact api
    app.post '/api/contact',               api.public.contact

    # login/signup api
    app.post '/api/session',               api.login.login
    app.del  '/api/session',               api.login.logout
    app.get  '/api/signup/validate',       api.login.validate_email
    app.post '/api/signup',                api.login.signup
    app.post '/api/reset',                 api.login.reset

    app.post '/api/profile',               api.profile.update

    # admin system
    app.get  '/admin',                             routes.admin.middleware, routes.admin.index
    app.get  '/admin/users',                       routes.admin.middleware, routes.admin.users
    app.post '/admin/users/:id',                   routes.admin.middleware, routes.admin.profile
    app.get  '/admin/users/:id/impersonate',       routes.admin.middleware, routes.admin.impersonate