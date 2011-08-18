
/**
 * Module dependencies.
 */

var express = require('express');
var ejs = require('ejs');

var app = module.exports = express.createServer();

// Configuration
var pub = __dirname + '/public';

app.configure(function() {
    app.set('view engine', 'ejs');
    app.use(express.bodyParser());
    app.use(express.methodOverride());
    app.use(express.static(pub));
    app.use(app.router);
});


app.configure('development', function() {
    app.use(express.errorHandler({ dumpExceptions: true, showStack: true })); 
});

app.configure('production', function() {
    app.use(express.errorHandler()); 
});

// Routes

app.get('/', function(req, res) {
    res.render('index', {
        title: 'Express'
    });
});

app.listen(3000);
console.log("Express server listening on port %d in %s mode", app.address().port, app.settings.env);
