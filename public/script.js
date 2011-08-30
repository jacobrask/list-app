(function() {
$(document).ready(function() {

var socket = io.connect('http://109.74.6.47:3000');
var listId = 0;
socket.emit('domReady', listId);
//history.pushState(null, null, listId);

var inputToObject = function(el) {
    var obj = { type: $(el).attr('type'),
                value: $(el).val(),
                id: $(el).data('id'),
                listId: listId };
    if ($(el).attr('type') === 'checkbox') {
        // checkbox toggles "state"
        // 1 is open, 0 is done, -1 is removed
        obj['type'] = 'state';
        if ($(el).attr('checked')) {
            obj['value'] = 0;
        } else {
            obj['value'] = 1;
        }
    }
    return obj;
};

var addItem = function(item) {
    var liEl    = $('<li/>'),
        fieldEl = $('<fieldset/>');
        checkEl = $('<input type="checkbox">'),
        numEl   = $('<input type="number">'),
        textEl  = $('<input type="text">');
    $(checkEl).add(numEl).add(textEl).data('id', item.id);
    if (item.state == 0) {
        $(checkEl).attr('checked', true);
        $(fieldEl).addClass('checked');
    }
    $(numEl).val(item.number);
    $(textEl).val(item.text);
    $(checkEl).add(numEl).add(textEl).change(function() {
        socket.emit('itemChange', inputToObject($(this)));
    });
    $(checkEl).change(function() {
        $(this).parents('fieldset').toggleClass('checked');
    });
    $(textEl).change(function() {
        if($(this).parents('li').is(':last-child')) {
            socket.emit('requestEmptyItem', { listId: listId });
        }
    });
    $(fieldEl).append(checkEl, numEl, textEl);
    $(liEl).append(fieldEl);

    $('.list').append(liEl);
}

socket.on('newItem', addItem);

});
})();
