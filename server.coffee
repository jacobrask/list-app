port = process.env.PORT or 3000
require('zappa') port, ->
    enable 'serve jquery'
    use 'static'
    @_ = require 'underscore'
   
    include 'app'
