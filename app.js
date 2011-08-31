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
io.configure(function() {
    io.set('hearbeats', false);
});

// Database
rdb.on("error", function (err) {
    console.log("Redis connection error to " +
                 rdb.host + ":" + rdb.port + " - " + err);
});

// Iterate through set
var db_iterSet = function(key, action) {
    rdb.smembers(key, function(err, data) {
        // remember which item is the last in the list and tell callback
        var last = false,
            count = data.length;
        data.forEach(function(item, last) {
            count--;
            if (count == 0) {
                last = true;
            }
            action(item, last);
        });
    });
};

// perform an action on hash data
var db_doHash = function(key, action) {
    rdb.hgetall(key, function(err, data) {
        action(data);
    });
};

io.sockets.on('connection', function (socket) {
    var addEmptyItem = function(listId, broadcast) {
        rdb.incr('item:next', function(err, id) {
            var newItem = { id: id, state: 1, number: 1, text: '' };
            rdb.hmset('item:' + newItem.id, newItem, redis.print);
            rdb.sadd('list:' + listId + ':items', id, redis.print);
            if (broadcast) {
                socket.broadcast.emit('newItem', newItem);
                }
            socket.emit('newItem', newItem);
        });
    };
    socket.on('domReady', function(data) {
        // send items
        var listId = data,
            setKey = 'list:' + listId + ':items';
        rdb.scard(setKey, function(err, count) {
            if (count > 0) {
                db_iterSet(setKey, function(itemId, last) {
                    var itemKey = 'item:' + itemId;
                    db_doHash(itemKey, function(item) {    
                        item['id'] = itemId;
                        socket.emit('newItem', item);
                        if (last === true && item.text !== '') {
                            addEmptyItem(listId);
                        }
                    });
                });
            } else {
                addEmptyItem(listId);
            }
        });
    });
    socket.on('itemChange', function(data) {
        rdb.hset('item:' + data.id, data.type, data.value, redis.print);
        socket.broadcast.emit('updateItem', data);
    });
    socket.on('requestEmptyItem', function(data) {
        addEmptyItem(data.listId, true);
    });
});


// Routes

app.get('/', function (req, res) {
    res.render('index', {
        title: '1 List'
    });
});

app.listen(3000);
