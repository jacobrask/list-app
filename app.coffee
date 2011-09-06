@include = ->
    
    include 'db'
    db_forEach = @db_forEach
    def { db_forEach }
    db_setHashField = @db_setHashField
    def { db_setHashField }
    db_insertEmptyItem = @db_insertEmptyItem
    def { db_insertEmptyItem }


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
        h1 'untitled'
        ul class: 'list'


    # get list item and send to client
    def sendItem: (itemId, callback) ->
        itemKey = 'item:' + itemId
        db_forEach itemKey, (err, item) ->
            throw err if err
            item['id'] = itemId
            callback item

    at 'domReady': ->
        # send all current items to client
        listId = @listId
        setKey = 'list:' + listId + ':items'
        db_forEach setKey,
            (err, itemId) ->
                throw err if err
                sendItem itemId, (item) ->
                    emit 'renderItem', item: item
            (err, key) ->
                db_insertEmptyItem key, (err, item) ->
                    throw err if err
                    sendItem itemId, (item) ->
                        emit 'renderItem', item: item
   
    at 'updateItem': ->
        db_setHashField 'item:' + @item.id, @item.type, @item.value, (err, item) ->
            throw err if err
    
    at 'insertEmptyItem': ->
        db_insertEmptyItem 'list:' + @listId + ':items', (err, item) ->
            throw err if err


    # CLIENT SIDE APP LOGIC
    client '/index.js': ->
        connect()
        
        listId = 0

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
            itemId = item['id']
            liEl    = $('<li/>')
            checkEl = $('<input type="checkbox">')
            checkLabel = $('<label />')
            numEl   = $('<input type="number" min="1">')
            textEl  = $('<input type="text">')
            $(liEl).attr('id', 'item-' + item['id'])
            $(checkEl).add(numEl).add(textEl).data('id', itemId)
            $(checkEl).attr('id', 'checkbox-' + itemId)
            $(checkLabel).attr('for', $(checkEl).attr('id'))
            if item.state is '0'
                $(checkEl).prop('checked', true)
                $(liEl).addClass('checked')
            $(numEl).val(item.number)
            $(textEl).val(item.text)
            $(checkEl).add(numEl).add(textEl).change ->
                emit 'updateItem', item: inputToObject($(this))
            $(checkEl).change ->
                if $(this).prop('checked')
                    $(this).parents('li').addClass('checked')
                    $(this).parents('li').fadeOut('fast')
                    $(this).parents('li').promise().done(->
                        $(this).appendTo('.list')
                        $(this).fadeIn()
                    )
                else
                    $(this).parents('li').removeClass('checked')
                    $(this).parents('li').fadeOut('fast')
                    $(this).parents('li').promise().done(->
                        $(this).prependTo('.list')
                        $(this).fadeIn()
                    )

            $(textEl).change ->
                if $(this).parents('li').is(':last-child')
                    emit 'insertEmptyItem', listId: listId
            $(liEl).append(checkEl, checkLabel, numEl, textEl)
            if item.state is '0'
                if $('.list :checked').length > 0
                    $('.list :checked').last().parents('li').after($(liEl))
                else
                    $(liEl).appendTo('.list')
            else
                if $('.list not(:checked)').length > 0
                    $('.list not(:checked)').last().parents('li').after($(liEl))
                else
                    if $('.list :checked').length > 0
                        $(liEl).prependTo('.list')
                    else
                        $(liEl).appendTo('.list')
