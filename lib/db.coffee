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
    @db = db
    
    # iterate through something in the database
    db.forEach = (key, callback, fallback) ->
        rdb.exists key, (err, exists) ->
            return callback err if err
            # if there's nothing at 'key', perform fallback function
            if exists is 0
                return fallback null, key
            rdb.type key, (err, type) ->
                switch type
                    when 'set'
                        rdb.smembers key, (err, elements) ->
                            callback err, itemId for itemId in elements
                    when 'hash'
                        rdb.hgetall key, (err, data) ->
                            callback err, data
                    when 'string'
                        rdb.get key, (err, element) ->
                            callback err, element
                    else
                        callback err ? new Error "Invalid data type at key"


    # update an arbitrary field in database, check for data type
    db.set = (key, data, callback) ->
        rdb.type key, (err, type) ->
            if typeof data in ['string', 'number', 'boolean']
                # String
                # for new fields, assume string type
                switch type
                    when 'string', 'none'
                        if typeof data is 'boolean'
                            data = if true then 1 else 0
                        rdb.set key, data, (err) ->
                            callback err if err
                    when 'set'
                        rdb.sadd key, data, (err) ->
                            callback err if err
                    when 'zset'
                        rdb.zadd key, data, (err) ->
                            callback err if err

            else if Array.isArray(data)
                # Lists and sets
                # for new fields, assume list type
                switch type
                    when 'list', 'none'
                        rdb.rpush key, data, (err) ->
                            callback err if err
                    when 'set'
                        rdb.sadd key, data, (err) ->
                            callback err if err
                    when 'zset'
                        rdb.zadd key, data, (err) ->
                            callback err if err

            # Hashes
            else if data? and typeof data is 'object' and (type in ['hash', 'none'])
                rdb.hmset key, data, (err) ->
                    callback err
            else
                callback err ? new Error "Key exists and data types do not match"


    # increment a counter and return new value
    db.nextId = (key, callback) ->
        rdb.incr key, (err, id) ->
            callback err, id


    # insert an empty item at the end of a list
    db.insertEmptyItem = (key, callback) ->
        listKey = key
        db.nextId 'item:next', (err, itemId) ->
            return callback err if err
            item = { state: 1, number: 1, text: '', id: itemId }
            itemKey = 'item:' + itemId
            db.set itemKey, item, (err) ->
                return callback err if err
                rdb.sadd listKey, itemId, (err) ->
                    return callback err, itemId
