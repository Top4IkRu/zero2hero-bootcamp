const ethers = require("ethers");

main().then(async () => {
    console.log("===================");
});

async function main() {
    let prefix = 'zero2hero';
    let nonce = 0;
    let twoZero = false;
    while (true){
        let bytes = ethers.toUtf8Bytes(prefix + nonce);
        let hash_str = ethers.sha256(bytes);
        if (hash_str.startsWith('0x00000')) {
            console.log(`Found nonce: ${nonce}`)
            console.log(`Hash value: ${hash_str}`)
            break;
        } else if (hash_str.startsWith('0x00') && !twoZero) {
            console.log(`Found nonce: ${nonce}`)
            console.log(`Hash value: ${hash_str}`)
            twoZero = true;
        }
        nonce++;
    }
}
