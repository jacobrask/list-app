require('zappa') ->
    enable 'serve jquery'

    configure ->
        set views: "#{__dirname}/views", 'view engine': 'ejs'
        app.register '.ejs', zappa.adapter 'ejs'
        use 'bodyParser', 'methodOverride', app.router, 'static'

    configure
        development: -> use errorHandler: {dumpExceptions: on, showStack: on}
        production: -> use 'errorHandler'

    @redis = require 'redis'
    @rdb = @redis.createClient()
    @rdb.on 'error', (err) ->
        console.log 'Redis connection error: ' + err
    
    get '/': ->
        @title = '1 list'
        render 'index'

    include 'app'
