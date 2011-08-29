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
        var last = false;
        var count = data.length;
        data.forEach(function(item) {
            count--;
            if (count <= 0) {
                last = true;
            }
            action(item, last);
        });
    });
};

// do stuff with hash data
var mapHash = function(key, action) {
    rdb.hgetall(key, function(err, data) {
        action(data);
    });
};


// Routes

var list = [];
app.get('/:id', function(req, res) {
    var id = req.params.id;
    iterSet('list:' + id + ':items', function(item, last) {
        mapHash('item:' + item, function(li) {
            // build list
            list[item] = li;
        });
        if (last) {
            renderPage(list);
            list = [];
        }
    });
    var renderPage = function(data) {
        res.render('index', {
            title: '1 List',
            list: data
        });
    }
});

app.listen(3000);
