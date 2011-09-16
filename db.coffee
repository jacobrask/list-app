@include = ->

    # for RedisToGo / Heroku
    if process.env.REDISTOGO_URL
        rtg = require("url").parse(process.env.REDISTOGO_URL)
        rdb = require("redis").createClient(rtg.port, rtg.hostname)
        rdb.auth(rtg.auth.split(":")[1])
    else
        rdb = require("redis").createClient()

    rdb.on 'error', (err) ->
        console.log 'Redis connection error: ', err
    
    db = {}
    
    # iterate through something in the database
    db.forEach = (key, callback, fallback) ->
        rdb.exists key, (err, exists) ->
            return callback err if err
            # if there's nothing at 'key', perform fallback function
            if exists is 0
                return fallback null, key
            rdb.type key, (err, type) ->
                return callback err if err
                if type is 'set'
                    rdb.smembers key, (err, elements) ->
                        callback err, itemId for itemId in elements
                else if type is 'hash'
                    rdb.hgetall key, (err, data) ->
                        callback err, data
                else if type is 'string'
                    rdb.get key, (err, element) ->
                        callback err, element
                else
                    return callback new Error "Invalid data type at key", key

    # update a single item property
    db.setHashField = (key, field, value, callback) ->
        rdb.hset key, field, value, (err, data) ->
            callback err, key

    # increment a counter and return new value
    db.nextId = (key, callback) ->
        rdb.incr key, (err, id) ->
            callback err, id

    # insert an empty item at the end of a list
    db.insertEmptyItem = (key, callback) ->
        listKey = key
        db.nextId 'item:next', (err, itemId) ->
            callback err if err
            item = { state: 1, number: 1, text: '', id: itemId }
            itemKey = 'item:' + itemId
            rdb.hmset itemKey, item, (err) ->
                callback err if err
                rdb.sadd listKey, itemId, (err)->
                    callback err, itemId
    @db = db
