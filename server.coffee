require('zappa') ->
    enable 'serve jquery'
    use 'static'
    @_ = require 'underscore'
    get '/': ->
        @title = 'list'
        render 'index'

    include 'app'
