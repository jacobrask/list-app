@include = ->

    redis = @redis
    rdb   = @rdb


    # VIEWS
    view layout: ->
        doctype 5
        html ->
            head ->
                meta charset: 'utf-8'
                title @title
                meta name: 'viewport', content: 'width=device-width,initial-scale=1.0'
                link rel: 'stylesheet', href: 'http://fonts.googleapis.com/css?family=Delius'
                link rel: 'stylesheet', href: '/style.css'
                script src: '/socket.io/socket.io.js'
                script src: '/zappa/jquery.js'
                script src: '/zappa/zappa.js'
                script src: '/index.js'
        body ->
            @body

    view index: ->
        h1 class: 'unchanged', 'untitled'
        ul class: 'list'


    # SERVER SIDE APP LOGIC
    forEachInSet = (key, callback, fallback) ->
        rdb.scard key, (err, count) ->
            if count > 0
                rdb.smembers key, (err, elements) ->
                    # remember which element is the last in the set and tell callback
                    last = false
                    count = elements.length
                    elements.forEach (element, last) ->
                        last = true if --count is 0
                        callback element, last
            else
                fallback key
    def {forEachInSet}

    forEachInHash = (key, callback) ->
        rdb.hgetall key, (err, data) ->
            callback data
    def {forEachInHash}

    # insert an empty item at the end of a list
    insertEmptyItem = (listId, toAll) ->
        listKey = 'list:' + listId + 'items'
        rdb.incr 'item:next', (err, itemId) ->
            item = { state: 1, number: 1, text: '', id: itemId }
            itemKey = 'item:' + itemId
            rdb.hmset itemKey, item, redis.print
            rdb.sadd listKey, itemId, redis.print
            if toAll
                broadcast 'itemInserted', item: item
            io.sockets.emit 'itemInserted', item: item
    def {insertEmptyItem}

    # get list item and send to client
    def sendItem: (itemId, last) ->
        itemKey = 'item:' + itemId
        forEachInHash itemKey, (item) ->
            item['id'] = itemId
            io.sockets.emit 'renderItem', item: item
            insertEmptyItem @listId if (last and item.text)

    # updates a single item property and tells client
    def updateItem: (item) ->
        itemKey = 'item:' + item.id
        rdb.hset itemKey, item.type, item.value, ->
            broadcast 'itemUpdated', item: @item

    at 'domReady': ->
        # send all current items to client
        setKey = 'list:' + @listId + ':items'
        forEachInSet setKey, sendItem, insertEmptyItem

    at 'updateItem': ->
        updateItem @item

    at 'insertEmptyItem': ->
        insertEmptyItem @listId, true


    # CLIENT SIDE APP LOGIC
    client '/index.js': ->
        connect()
        
        listId = 0

        at 'itemUpdated': ->
            updateItem @item
        
        at 'itemInserted': ->
            renderItem @item
        
        at 'renderItem': ->
            renderItem @item
 
        $ ->
            emit 'domReady', listId: listId
        
        # convert an input element to an object suitable for sending server side
        inputToObject = (el) ->
            obj =
                type: $(el).attr('type')
                value: $(el).val()
                id: $(el).data('id')
                listId: listId
            if $(el).attr('type') is 'checkbox'
                # checkbox toggles "state"
                # 1 is open, 0 is done
                obj['type'] = 'state'
                if $(el).prop('checked')
                    obj['value'] = 0
                else
                    obj['value'] = 1
            obj
 
        # generate a list item and add all relevant events
        def renderItem: (item) ->
            liEl    = $('<li/>')
            fieldEl = $('<fieldset/>')
            checkEl = $('<input type="checkbox">')
            checkBoxEl = $('<span>✓</span>')
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
                emit 'insertEmptyItem', listId: listId
            $(fieldEl).append(checkBoxEl, checkEl, numEl, textEl)
            $(liEl).append(fieldEl)
            $('.list').append(liEl)
 
        # updates only relevant item field only
        def updateItem: (item) ->
            liEl = $('#item-' + item['id'])
            if item.type is 'state'
                checkbox = $(liEl).children(':checkbox')
                $(checkbox).prop('checked', !$(checkbox).prop('checked'))
            else
                $(liEl).find('input[type=' + item.type + ']').val(item.value)
