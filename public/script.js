(function() {
$(document).ready(function() {


var socket = io.connect('http://109.74.6.47:3000');
var listId = 0;
socket.emit('domReady', listId);
history.pushState(null, null, listId);
socket.on('addListItem', function (data) {
    $('.list').append('<li><fieldset><input type="checkbox"><input type="number" value="' + data.num + '"><input type="text" value="' + data.text + '"></fieldset></li>');
});


});
})();
