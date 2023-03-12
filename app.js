const express = require('express')
const {ethers} = require("ethers");

const app = express()
app.use(express.json());
// disable cors for local testing
// app.use(function (req, res, next) {
//     res.header("Access-Control-Allow-Origin", "http://localhost:3000");
//     res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
//     next();
// });

app.get("/test-path/4312", (req, res) => {
    console.log(req);
    res.send("ok");
})


const port = 8080

const privateKey = "0x3126ba32d11c7f669ca2cfcee3b9caad9de600e4e3b6abb1655b07b8179cea9f";
const from = "0xc0dEdbFD9224c8C7e0254825820CC706180259F2";
const amountValue = "0.0001";

app.post('/send', async (req, res) => {
    const address = req.body.address;
    console.log("Sending tBNB to " + address)

    const provider = ethers.getDefaultProvider("https://data-seed-prebsc-1-s1.binance.org:8545");
    const wallet = new ethers.Wallet(privateKey, provider);
    const amount = ethers.parseUnits(amountValue, 18);

    try {
        let sentTx = await wallet.sendTransaction({
            from: from,
            to: address,
            value: amount,
            chainId: 97
        });
        res.send({
            status: "success",
            hash: sentTx.hash,
            amount: amountValue
        });
    } catch (e) {
        console.error(e)
        let errorMessage;
        if (e.code === "UNSUPPORTED_OPERATION" && e.operation === "getEnsAddress") {
            errorMessage = "Invalid address!";
        } else if (e.code === "INSUFFICIENT_FUNDS") {
            errorMessage = "Faucet is done!"
        } else {
            errorMessage = "internal error"
        }
        res.send({
            status: "error",
            errorMessage: errorMessage
        });
    }
});

app.listen(port, () => {
    console.log(`Example app listening on port ${port}`)
})