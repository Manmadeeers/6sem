const express = require('express');
const crypto = require('crypto');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const PORT = 3000;

const sessions = new Map();
const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', {
    modulusLength: 2048,
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
});


const app = express();
app.use(express.json());

app.get('/init', (req, res) => {
    const sessionId = uuidv4();

    sessions.set(sessionId, { publicKey, privateKey, step: 1 });

    console.log(`Session with session id ${sessionId} initialized`);

    res.json({ sessionId, publicKey });
});

app.get('/resource', (req, res) => {
    const sessionID = req.query.sessionID;
    if (!sessionID || !sessions.has(sessionID)) {
        res.status(409).json({ error: "Unable to find session. Protocol violation" });
    }

    if (sessions.get(sessionID).step != 1) {
        res.status(409).json({ error: "Invalid protocol step. Protocol violation" });
    }
    else {
        sessions.get(sessionID).step = 2;
    }
    try {
        const text = fs.readFileSync("./toSend.txt");
        const data = Buffer.from(text);

        const signature = crypto.sign("SHA256", data, privateKey);

        res.json({
            data: text,
            signature: signature.toString('base64')
        });
    }
    catch (err) {
        res.status(500).json({ error: "Internal server error" });
        console.error("Error: ", err.message);
    }

});


app.listen(PORT, () => {
    console.log(`Server listening at http://localhost:${PORT}/`)
})


