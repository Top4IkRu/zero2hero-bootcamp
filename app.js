const express = require('express');
const {ethers} = require("ethers");
const AWS = require("aws-sdk")
const sls = require('serverless-http');
const axios = require("axios");

const app = express()
app.use(express.json());
// disable cors for local testing
app.use(function (req, res, next) {
    res.header("Access-Control-Allow-Origin", "https://bnb-faucet-amber.vercel.app");
    res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
    next();
});

const dynamoDB = new AWS.DynamoDB({
    region: "us-east-1",
})

const privateKey = "0x0a9f83caeafc1350bf93c3bf0c93fff20c4562c075b4628b57c9b42e7b4e3e96";
const from = "0xc0dec91957A1839E899f0318440192D7E618c26C";
const amountValue = "0.05";

const googleCaptureSecret = process.env.CAPTURE_SECRET

async function isValidToken(token) {
    try {
        let response = await axios.post(`https://www.google.com/recaptcha/api/siteverify?secret=${googleCaptureSecret}&response=${token}`);
        console.log('Google response = ' + JSON.stringify(response.data));
        return response.data.success;
    } catch (error) {
        console.error(error);
        return false;
    }
}

app.post('/send', async (req, res) => {
    const address = req.body.address;
    const token = req.body.captureToken;
    console.log("Sending tBNB to " + address);
    console.log("Token " + token);

    const items = await dynamoDB.scan({TableName: "BnbFaucet"}).promise().then(data => data.Items)
    const lastTx = items.find(item => item.address.S === address)

    const verificationStatus = await isValidToken(token);
    if (!verificationStatus) {
        res.send({
            status: "error",
            errorMessage: 'Capture token is invalid. Please try again.'
        });
        return;
    }

    if (lastTx !== undefined) {
        const lastTxDate = new Date(Number(lastTx.instant.N));
        const lastTxIsOk = new Date().getTime() - lastTxDate > 43200000;
        if (!lastTxIsOk) {
            const nextPayoutDate = new Date(lastTxDate.getTime() + 43200000);
            res.send({
                status: "error",
                errorMessage: 'You have recently received coins. Next payout in ' +
                    nextPayoutDate.toLocaleDateString() + ' ' + nextPayoutDate.toLocaleTimeString()
            });
            return;
        }
    }


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

        await dynamoDB.putItem({
            TableName: "BnbFaucet",
            Item: {
                address: {
                    S: address
                },
                amount: {
                    S: amountValue
                },
                instant: {
                    N: new Date().getTime().toString()
                }
            },
        })
            .promise()
            .then(data => console.log(data))
            .catch(console.error)

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

const port = 8080
app.listen(port, () => {
    console.log(`Example app listening on port ${port}`)
})

module.exports.server = sls(app)