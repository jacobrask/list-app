@include = ->
    
    include 'lib/db'
    db = @db
    def { db }

    list = []
    def { list }

    # requested a list ID directly
    get /^\/(\d+)/, ->
        list['id'] = params[0]
        render 'index'
   
    # redirect to next available list id url
    get '/': ->
        db.nextId 'list:next', (err, nextListId) ->
            throw err if err
            redirect '/' + nextListId

    # VIEWS
    view layout: ->
        doctype 5
        #html manifest: 'default.appcache', ->
        html ->
            head ->
                meta charset: 'utf-8'
                title 'list'
                meta name: 'viewport',
                     content: 'width=device-width,initial-scale=1.0'
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
        item = {}
        item[@item.type] = @item.value
        db.set 'item:' + @item.id, item, (err, item) ->
            throw err if err
 
    at 'updateTitle': ->
        key = 'list:' + list['id'] + ':title'
        db.set key, @listTitle, (err) ->
            throw err if err
   
    at 'requestEmptyItem': ->
        key = 'list:' + list['id'] + ':items'
        db.insertEmptyItem key, (err, itemId) ->
            throw err if err
            sendItem itemId, (item) ->
                emit 'renderItem', item: item


    # CLIENT SIDE APP LOGIC
    client '/script.js': ->

        connect()
        
        at 'renderItem': ->
            renderItem @item
        
        at 'sendTitle': ->
            setTitle @listTitle

        $ ->
            emit 'domReady'
        
        # convert input element to object
        inputToObject = (el) ->
            obj =
                type: $(el).attr('type')
                value: $(el).val()
                id: $(el).data('id')
            if $(el).attr('type') is 'checkbox'
                # checkbox toggles "state"
                # 1 is open, 0 is done
                obj['type'] = 'state'
                obj['value'] = if $(el).prop('checked') then 0 else 1
            return obj
 
        # generate a list item and add events
        def renderItem: (item) ->
            itemId = item['id']
            $list = $('.list')
            $liEl = $('<li/>')
            $checkEl = $('<input type="checkbox">')
            $checkLabel = $('<label for="checkbox-' + itemId + '"/>')
            $numEl = $('<input type="number" min="1">')
            $textEl = $('<input type="text">')
            if item.state is '0'
                $checkEl.prop('checked', true)
                $liEl.addClass('checked')
            $numEl.val(item.number)
            $textEl.val(item.text)
            $checkEl
                .attr('id', 'checkbox-' + itemId)
                .add($numEl)
                .add($textEl)
                .data('id', itemId)
                .change ->
                    $this = $(@)
                    $pLi = $this.parents('li')
                    # request a new empty item if this is the only item,
                    # next list item is checked, and this item's text is empty
                    if ($pLi.is(':last-child') or
                    $pLi.next().hasClass('checked')) and not
                    $pLi.hasClass('checked') and
                    (($this.is('input[type=text]') and $this.val() isnt '') or
                    $this.siblings('input[type=text]').val() isnt '')
                        emit 'requestEmptyItem'
                    emit 'updateItem', item: inputToObject($this)

            $checkEl.change ->
                $this = $(@)
                $this.parents('li')
                    .fadeOut('fast')
                    .promise().done ->
                        $this = $(@)
                        if $this.children('[type=checkbox]').prop('checked')
                            $this
                                .addClass('checked')
                                .appendTo($list)
                        else
                            $this
                                .removeClass('checked')
                                .prependTo($list)
                        $this.fadeIn()

            $liEl.append($checkEl, $checkLabel, $numEl, $textEl)

            $checkedLis = $('.list li.checked')
            $uncheckedLis = $('.list li:not(.checked)')
            # if list is empty, or if item is the first checked item, append
            if $('.list li').length is 0 or
            (item.state is '0' and $checkedLis.length is 0)
                $liEl.appendTo($list)
            # if item is checked,
            # add after last checked item
            else if item.state is '0'
                $checkedLis.last().after($liEl)
            # if item is unchecked,
            # add after last unchecked item or first in list
            else if item.state is '1'
                if $uncheckedLis.length > 0
                    $uncheckedLis.last().after($liEl)
                else
                    $liEl.prependTo($list)

        def setTitle: (title) ->
            $('title').text(title)
            $('h1[contenteditable]')
                .text(title)
                .data('before', title) # set initial value
                .bind 'blur keyup paste', ->
                    # trigger change event if title has changed from previous
                    # value stored in data
                    $this = $(@)
                    if $this.data('before') isnt $this.text()
                        $this
                            .data('before', $this.text())
                            .trigger('change')
                        $this
                .change ->
                    $this = $(@)
                    $('title').text($this.text())
                    emit 'updateTitle', listTitle: $this.text()
