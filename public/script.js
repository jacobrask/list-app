(function() {
$(document).ready(function() {

var socket = io.connect('http://109.74.6.47:3000');
var listId = 0;
socket.emit('domReady', listId);
//history.pushState(null, null, listId);

var inputToObject = function(el) {
    var obj = { type: $(el).attr('type'),
                value: $(el).val(),
                id: $(el).data('id') };
    if ($(el).attr('type') === 'checkbox') {
        obj['type'] = 'state';
        if ($(el).attr('checked')) {
            obj['value'] = 0;
        } else {
            obj['value'] = 1;
        }
    }
    return obj;
};

var addItem = function(data) {
    var liEl    = $('<li/>'),
        fieldEl = $('<fieldset/>');
        checkEl = $('<input type="checkbox">'),
        numEl   = $('<input type="number">'),
        textEl  = $('<input type="text">');
    $(checkEl).add(numEl).add(textEl).data('id', data.id);
    if (data.li.state == 0) {
        $(checkEl).attr('checked', true);
    }
    $(numEl).val(data.li.number);
    $(textEl).val(data.li.text);
    $(checkEl).add(numEl).add(textEl).change(function() {
        socket.emit('itemChange', inputToObject($(this)));
    });
    $(fieldEl).append(checkEl, numEl, textEl);
    $(liEl).append(fieldEl);
    $('.list').append(liEl);
}
    
socket.on('newItem', addItem);

});
})();
