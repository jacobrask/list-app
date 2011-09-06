require('zappa') ->
    enable 'serve jquery'
 
    use 'static'
 
    get '/': ->
        @title = 'list'
        render 'index'

    include 'common'
    include 'app'
