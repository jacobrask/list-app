@include = ->

    rdb = require('redis-url').connect(process.env.REDISTOGO_URL);
    rdb.on 'error', (err) ->
        console.log 'Redis connection error: ', err
    
    _ = @_
    db = {}
    
    # iterate through something in the database
    db.forEach = (key, callback, fallback) ->
        rdb.exists key, (err, exists) ->
            if err
                return callback err
            # if there's nothing at 'key', perform fallback function
            if exists is 0
                return fallback null, key
            rdb.type key, (err, type) ->
                if err
                    return callback err
                if type is 'set'
                    rdb.smembers key, (err, elements) ->
                        if err
                            return callback err
                        # remember which element is the last in the set and tell callback
                        _.forEach elements, (itemId) ->
                            callback null, itemId
                else if type is 'hash'
                    rdb.hgetall key, (err, data) ->
                        if err
                            return callback err
                        return callback null, data
                else if type is 'string'
                    rdb.get key, (err, element) ->
                        if err
                            return callback err
                        return callback null, element
                else
                    return callback new Error("Invalid data type at key", key)
                    
    # update a single item property
    db.setHashField = (key, field, value, callback) ->
        rdb.hset key, field, value, (err, data) ->
            if err
                callback err
            callback null, key

    # increment a counter and return new value
    db.nextId = (key, callback) ->
        rdb.incr key, (err, id) ->
            if err
                callback err
            callback null, id

    # insert an empty item at the end of a list
    db.insertEmptyItem = (key, callback) ->
        listKey = key
        db_nextId 'item:next', (err, itemId) ->
            if err
                callback err
            item = { state: 1, number: 1, text: '', id: itemId }
            itemKey = 'item:' + itemId
            rdb.hmset itemKey, item, ->
                rdb.sadd listKey, itemId, ->
                    callback null, itemId
    @db = db
