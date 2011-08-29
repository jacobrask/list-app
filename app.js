// Module dependencies.
var express = require('express');
var ejs = require('ejs');
var redis = require('redis');
var rdb = redis.createClient();

var app = module.exports = express.createServer();

// Configuration
app.configure(function() {
    app.set('view engine', 'ejs');
    app.use(express.bodyParser());
    app.use(express.methodOverride());
    app.use(express.static(__dirname + '/public'));
    app.use(app.router);
});

app.configure('development', function() {
    app.use(express.errorHandler({ dumpExceptions: true, showStack: true })); 
});

app.configure('production', function() {
    app.use(express.errorHandler()); 
});

// Database
rdb.on("error", function (err) {
    console.log("Redis connection error to " + rdb.host + ":" + rdb.port + " - " + err);
});

// iterate through set
var iterSet = function(key, action) {
    rdb.smembers(key, function(err, data) {
        data.forEach(function(item) {
            action(item);
        });
    });
};

// do stuff with hash data
var mapHash = function(key, action) {
    rdb.hgetall(key, function(err, data) {
        action(data);
    });
};

iterSet('list:0:items',
    function(item) {
        mapHash('item:' + item,
            function(li) {
                // build list
            }
        );
    }
);

// Routes

app.get('/', function(req, res) {
    res.render('index', {
        title: '1 List',
        list: []
    });
});

app.listen(3000);
console.log("Express server listening on port %d in %s mode", app.address().port, app.settings.env);
