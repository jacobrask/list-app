require('zappa') ->
    enable 'serve jquery'
    use 'static'
    @_ = require 'underscore'
   
    include 'app'
