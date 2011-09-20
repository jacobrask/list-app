@include = ->
    
    include 'lib/db'
    db = @db
    def { db }

    list = []
    def { list }

    # requested a list ID directly
    get /^\/(\d+)/, ->
        list['id'] = params[0]
        @title = 'list ' + list['id']
        render 'index'
   
    # redirect to next available list id url
    get '/': ->
        db.nextId 'list:next', (err, nextListId) ->
            throw err if err
            redirect '/' + nextListId

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
                script src: '/script.js'
        body ->
            @body

    view index: ->
        h1 contenteditable: 'true'
        ul class: 'list'


    # get list item and send to client
    def sendItem: (itemId, callback) ->
        itemKey = 'item:' + itemId
        db.forEach itemKey, (err, item) ->
            throw err if err
            item['id'] = itemId
            callback item

    at 'domReady': ->
        # send all current items to client
        baseKey = 'list:' + list['id']
        db.forEach baseKey + ':items',
            (err, itemId) ->
                throw err if err
                sendItem itemId, (item) ->
                    emit 'renderItem', item: item
            (err, key) ->
                throw err if err
                db.insertEmptyItem key, (err, itemId) ->
                    throw err if err
                    sendItem itemId, (item) ->
                        emit 'renderItem', item: item

        # send list title
        db.forEach baseKey + ':title',
            (err, listTitle) ->
                throw err if err
                emit 'sendTitle', listTitle: listTitle
            (err, key) ->
                throw err if err
                emit 'sendTitle', listTitle: 'untitled list'


    at 'updateItem': ->
        db.setHashField 'item:' + @item.id, @item.type, @item.value, (err, item) ->
            throw err if err
 
    at 'updateTitle': ->
        key = 'list:' + list['id'] + ':title'
        db.set key, @listTitle, (err) ->
            throw err if err
   
    at 'insertEmptyItem': ->
        db.insertEmptyItem 'list:' + @listId + ':items', (err, item) ->
            throw err if err


    # CLIENT SIDE APP LOGIC
    client '/script.js': ->

        connect()
        
        at 'renderItem': ->
            renderItem @item
        
        at 'sendTitle': ->
            setTitle @listTitle

        $ ->
            emit 'domReady'
        
        # convert an input element to an object suitable for sending server side
        inputToObject = (el) ->
            obj =
                type: $(el).attr('type')
                value: $(el).val()
                id: $(el).data('id')
            if $(el).attr('type') is 'checkbox'
                # checkbox toggles "state"
                # 1 is open, 0 is done
                obj['type'] = 'state'
                if $(el).prop('checked')
                    obj['value'] = 0
                else
                    obj['value'] = 1
            return obj
 
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
                $(this).parents('li').fadeOut('fast')
                $(this).parents('li').promise().done(->
                    if $(this).children('[type=checkbox]').prop('checked')
                        $(this).addClass('checked')
                        $(this).appendTo('.list')
                    else
                        $(this).removeClass('checked')
                        $(this).prependTo('.list')
                    $(this).fadeIn()
                )

            $(liEl).append(checkEl, checkLabel, numEl, textEl)
            
            # if list is empty, or if item is the first checked item, append
            if $('.list li').length is 0 or (item.state is '0' and $('.list :checked').length is 0)
                $(liEl).appendTo('.list')
            # if item is checked, add after last checked item
            else if item.state is '0'
                $('.list :checked').last().parents('li').after($(liEl))
            # if item is unchecked, add after last unchecked item or first in list
            else if item.state is '1'
                if $('.list not(:checked)').length > 0
                    $('.list not(:checked)').last().parents('li').after($(liEl))
                else
                    $(liEl).prependTo('.list')

        def setTitle: (title) ->
            $('h1[contenteditable]')
                .text(title)
                .data('before', title)
                .bind 'blur keyup paste', ->
                    # trigger change event if title has changed from initial value
                    if $(this).data('before') isnt $(this).text()
                        $(this)
                            .data('before', $(this).text())
                            .trigger('change')
                        $(this)
                .change ->
                    emit 'updateTitle', listTitle: $(this).text()
