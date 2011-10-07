port = Number(process.env.PORT || 3000)
require('zappa') port, (z) ->
    z.set databag: 'this'
    z.enable 'serve jquery'
    z.use 'static'
   
    z.include 'lib/app'
