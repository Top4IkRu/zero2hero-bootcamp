const crypto = require('crypto');

function keyBySHA256(key) {
    return '0x' + crypto.createHash('sha256').update(key).digest('hex');
}

function encryptAES256(message, hexString) {
    if (hexString.startsWith("0x"))
        hexString = hexString.slice(2);
    let key = Buffer.from(hexString, "hex");
    const cipher = crypto.createCipheriv('aes-256-ecb', key, null);
    let encrypted = cipher.update(message, 'utf8', 'base64');
    encrypted += cipher.final('base64');
    return encrypted;
}

function decryptAES256(message, hexString) {
    if (hexString.startsWith("0x"))
        hexString = hexString.slice(2);
    let key = Buffer.from(hexString, "hex");
    const decipher = crypto.createDecipheriv('aes-256-ecb', key, '');
    let decrypted = decipher.update(message, 'base64', 'utf-8');
    decrypted += decipher.final('utf-8');
    return decrypted;
}

const message = ''
const key = '0xc0de'

const hashed_key = keyBySHA256(key)
console.log('Hashed key: ' + hashed_key);

const resultEncrypt = encryptAES256(message, hashed_key);
console.log('Encrypted result: ' + resultEncrypt);

const resultDecrypt = decryptAES256(resultEncrypt, hashed_key);
console.log('Decrypted result: ' + resultDecrypt);
