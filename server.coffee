require('zappa') ->
    enable 'serve jquery'
    
    use 'static'

    @redis = require 'redis'
    @rdb = @redis.createClient()
    @rdb.on 'error', (err) ->
        console.log 'Redis connection error: ' + err
    
    get '/': ->
        @title = 'list'
        render 'index'

    include 'app'
