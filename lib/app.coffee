@include = (z) ->
    
    z.include 'lib/db'
    db = @db

    list = []

    # requested a list ID directly
    z.get /^\/(\d+)/, ->
        list['id'] = params[0]
        z.render 'index'
   
    # redirect to next available list id url
    z.get '/': ->
        db.nextId 'list:next', (err, nextListId) ->
            throw err if err
            z.redirect '/' + nextListId

    # VIEWS
    z.view layout: ->
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
                script src: '/coffeekup.js'
                script src: '/script.js'
        body ->
            @body

    z.view index: ->
        h1 contenteditable: 'true'
        ul class: 'list', ->

    # get list item and send to client
    sendItem = (itemId, callback) ->
        itemKey = 'item:' + itemId
        db.forEach itemKey, (err, item) ->
            throw err if err
            item['id'] = itemId
            callback item

    z.on 'domReady': ->
        # send all current items to client
        baseKey = 'list:' + list['id']
        db.forEach baseKey + ':items',
            (err, itemId) ->
                throw err if err
                sendItem itemId, (item) ->
                    z.emit 'renderItem', item: item
            (err, key) ->
                throw err if err
                db.insertEmptyItem key, (err, itemId) ->
                    throw err if err
                    sendItem itemId, (item) ->
                        z.emit 'renderItem', item: item

        # send list title
        db.forEach baseKey + ':title',
            (err, listTitle) ->
                throw err if err
                z.emit 'sendTitle', listTitle: listTitle
            (err, key) ->
                throw err if err
                z.emit 'sendTitle', listTitle: 'untitled list'


    z.on 'updateItem': ->
        item = {}
        item[@item.type] = @item.value
        db.set 'item:' + @item.id, item, (err, item) ->
            throw err if err
 
    z.on 'updateTitle': ->
        key = 'list:' + list['id'] + ':title'
        db.set key, @listTitle, (err) ->
            throw err if err
   
    z.on 'requestEmptyItem': ->
        key = 'list:' + list['id'] + ':items'
        db.insertEmptyItem key, (err, itemId) ->
            throw err if err
            sendItem itemId, (item) ->
                z.emit 'renderItem', item: item


    # CLIENT SIDE APP LOGIC
    z.client '/script.js': ->

        connect()
 
        # CoffeeKup
        listItem = ->
            li ('class': 'checked' if @item.state is '0'), ->
                input type: 'checkbox', id: "checkbox-#{@item.id}", 'data-id': @item.id, checked: 'checked' if @item.state is '0'
                label for: "checkbox-#{@item.id}", 'data-id': @item.id
                input type: 'number', min: '1', value: @item.number, 'data-id': @item.id
                input type: 'text', value: @item.text, 'data-id': @item.id

        z.on 'renderItem': ->
            renderItem @item
        
        z.on 'sendTitle': ->
            setTitle @listTitle

        $ ->
            z.emit 'domReady'
        
        $list = $('.list')

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

        # Send update event to server
        $('.list input').live 'change', ->
            $input = $(@)
            $pLi = $input.parents('li')
            # request a new empty item if this is the only item,
            # next list item is checked, and this item's text is empty
            if ($pLi.is(':last-child') or
            $pLi.next().hasClass('checked')) and not
            $pLi.hasClass('checked') and
            (($input.is('input[type=text]') and $input.val() isnt '') or
            $input.siblings('input[type=text]').val() isnt '')
                z.emit 'requestEmptyItem'
            z.emit 'updateItem', item: inputToObject($input)
         
         # Move the element when state is toggled
         $('.list input[type=checkbox]').live 'change', ->
            $checkbox = $(@)
            $checkbox.parents('li')
                .fadeOut('fast')
                .promise().done ->
                    $li = $(@)
                    if $checkbox.prop('checked')
                        $li.addClass('checked').appendTo($list)
                    else
                        $li.removeClass('checked').prependTo($list)
                    $li.fadeIn()

        # Render and add an item to the right position in list
        renderItem = (item) ->
            $list = $('.list')
            ck_li = CoffeeKup.render(listItem, item: item)
            $ck_li = $(ck_li)

            $checkedLis = $('.list li.checked')
            $uncheckedLis = $('.list li:not(.checked)')
            # if list is empty, or if item is the first checked item, append
            if $('.list li').length is 0 or
            (item.state is '0' and $checkedLis.length is 0)
                $list.append($ck_li)
            # if item is checked,
            # add after last checked item
            else if item.state is '0'
                $checkedLis.last().after($ck_li)
            # if item is unchecked,
            # add after last unchecked item or first in list
            else if item.state is '1'
                if $uncheckedLis.length > 0
                    $uncheckedLis.last().after($ck_li)
                else
                    $list.prepend($ck_li)

        setTitle = (title) ->
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
                    z.emit 'updateTitle', listTitle: $this.text()
