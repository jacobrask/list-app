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

rdb.del('item:1');
rdb.del('item:2');
rdb.del('list:1:items');
rdb.hset('item:1', 'num', '12', redis.print);
rdb.hset('item:1', 'text', "Eggs", redis.print);
rdb.hset('item:1', 'status', '1', redis.print);
rdb.hset('item:2', 'num', '1', redis.print);
rdb.hset('item:2', 'text', "Milk", redis.print);
rdb.hset('item:2', 'status', '0', redis.print);
rdb.sadd('list:1:items', '1', redis.print);
rdb.sadd('list:1:items', '2', redis.print);

var list = [];

rdb.smembers('list:1:items', function(err, data) {
    if (err) {
        console.log('Redis error : ' + err);
    } else {
        for(var i = 0;i < data.length; i++) {
            rdb.hgetall('item:' + data[i], function(err, li) {
                if (err) {
                    console.log('Redis error : ' + err);
                } else {
                    list.push(li);
                }
            });
        }
    }
});

// Routes

app.get('/', function(req, res) {
    res.render('index', {
        title: '1 List',
        list: list
    });
});

app.listen(3000);
console.log("Express server listening on port %d in %s mode", app.address().port, app.settings.env);
