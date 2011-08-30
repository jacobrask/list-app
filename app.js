// Module dependencies.
var express = require('express');
var app = module.exports = express.createServer();
var io = require('socket.io').listen(app);

var ejs = require('ejs');
var redis = require('redis');
var rdb = redis.createClient();

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
var db_iterSet = function(key, action) {
    rdb.smembers(key, function(err, data) {
        data.forEach(function(item) {
            action(item);
        });
    });
};

// do stuff with hash data
var db_doHash = function(key, action) {
    rdb.hgetall(key, function(err, data) {
        action(data);
    });
};

io.sockets.on('connection', function (socket) {
    socket.on('domReady', function(data) {
        var listId = data;
        // send items
        db_iterSet('list:' + listId + ':items', function(itemId) {
            db_doHash('item:' + itemId, function(item) {
                item['id'] = itemId;
                socket.emit('newItem', item);
            });
        });
    });
    socket.on('itemChange', function(data) {
        rdb.hset('item:' + data.id, data.type, data.value, redis.print);
    });
});


// Routes

app.get('/', function (req, res) {
    res.render('index', {
        title: '1 List'
    });
});

app.listen(3000);
