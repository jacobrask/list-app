require('zappa') ->
    enable 'serve jquery'

    configure ->
        set views: "#{__dirname}/views", 'view engine': 'ejs'
        app.register '.ejs', zappa.adapter 'ejs'
        use 'bodyParser', 'methodOverride', app.router, 'static'

    configure
        development: -> use errorHandler: {dumpExceptions: on, showStack: on}
        production: -> use 'errorHandler'


    redis = require 'redis'
    rdb = redis.createClient()
    def {rdb}
    rdb.on 'error', (err) ->
        console.log 'Redis connection error: ' + err


    # iterate through set
    db_iterSet = (key, action, fallback) ->
        rdb.scard key, (err, count) ->
            if count > 0
                rdb.smembers key, (err, elements) ->
                    # remember which element is the last in the set and tell callback
                    last = false
                    count = elements.length
                    elements.forEach (element, last) ->
                        last = true if --count is 0
                        action element, last
            else
                fallback
    def {db_iterSet}

    # do something with hash data
    db_doHash = (key, action) ->
        rdb.hgetall key, (err, data) ->
            action data
    def {db_doHash}

    addEmptyItem = (listId, doBroadcast) ->
        rdb.incr 'item:next', (err, id) ->
            newItem = { id: id, state: 1, number: 1, text: '' }
            rdb.hmset 'item:' + newItem.id, newItem, redis.print
            rdb.sadd 'list:' + listId + ':items', id, redis.print
            if doBroadcast
                broadcast 'addItem', item: newItem
            io.sockets.emit 'addItem', item: newItem
    def {addEmptyItem}

    sendItem = (itemId, last) ->
        itemKey = 'item:' + itemId
        db_doHash itemKey, (item) ->
            item['id'] = itemId
            io.sockets.emit 'addItem', item: item
            addEmptyItem @listId if (last and item.text)
    def {sendItem}

    at 'domReady': ->
        # send items
        setKey = 'list:' + @listId + ':items'
        db_iterSet setKey, sendItem, addEmptyItem

    at 'updateItem': ->
        rdb.hset 'item:' + @item.id, @item.type, @item.value, ->
            broadcast 'updateItem', item: @item

    at 'requestEmptyItem': ->
        addEmptyItem @listId, true

    # CLIENT SIDE
    client '/index.js': ->
        connect()
        
        listId = 0

        at 'updateItem': ->
            updateItem @item
        
        at 'addItem': ->
            addItem @item

        $().ready ->
            emit 'domReady', listId: listId
        
        inputToObject = (el) ->
            obj =
                type: $(el).attr('type')
                value: $(el).val()
                id: $(el).data('id')
                listId: listId
            if $(el).attr('type') == 'checkbox'
                # checkbox toggles "state"
                # 1 is open, 0 is done, -1 is removed
                obj['type'] = 'state'
                if $(el).prop('checked')
                    obj['value'] = 0
                else
                    obj['value'] = 1
            obj
 
        addItem = (item) ->
            liEl    = $('<li/>')
            fieldEl = $('<fieldset/>')
            checkEl = $('<input type="checkbox">')
            numEl   = $('<input type="number" min="1">')
            textEl  = $('<input type="text">')
            $(liEl).attr('id', 'item-' + item['id'])
            $(checkEl).add(numEl).add(textEl).data('id', item['id'])
            if item.state is 0
                $(checkEl).prop('checked', true)
                $(fieldEl).addClass('checked')
            $(numEl).val(item.number)
            $(textEl).val(item.text)
            $(checkEl).add(numEl).add(textEl).change ->
                emit 'updateItem', item: inputToObject($(this))
            $(checkEl).change ->
                $(this).parents('fieldset').toggleClass('checked')
            $(textEl).change ->
            if $(this).parents('li').is(':last-child')
                emit 'requestEmptyItem', listId: listId
            $(fieldEl).append(checkEl, numEl, textEl)
            $(liEl).append(fieldEl)
            $('.list').append(liEl)

        def {addItem}
 
        updateItem = (item) ->
            liEl = $('#item-' + item['id'])
            if item.type == 'state'
                checkbox = $(liEl).children(':checkbox')
                $(checkbox).prop('checked', !$(checkbox).prop('checked'))
            else
                $(liEl).find('input[type=' + item.type + ']').val(item.value)

        def {updateItem}
       
    # Routes
    get '/': ->
        @title = '1 list'
        render 'index'
