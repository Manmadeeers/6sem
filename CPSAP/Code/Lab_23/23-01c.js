const crypto = require('crypto');
const axios = require('axios');
const fs = require('fs');
const dh = crypto.createDiffieHellman(2048);


async function runClient() {
    const start = await axios.get('http://localhost:3000/exchange');
    const { prime, generator, serverPublicKey, sessionID } = (await start).data;
    console.log('Received server DH params: ', { sessionID, prime, generator, serverPublicKey });

    const clientDH = crypto.createDiffieHellman(prime, generator);
    clientDH.generateKeys();
    const clientPublicKey = clientDH.getPublicKey('hex');

    await axios.post('http://localhost:3000/exchange', { sessionID, clientPublicKey: clientPublicKey });
    console.log("Client's public key sent to server");


    const serverPub = serverPublicKey;
    const sharedSecret = clientDH.computeSecret(serverPub);
    const key = crypto.createHash('sha256').update(sharedSecret).digest();

    const resource = await axios.get('http://localhost:3000/resource', { params: sessionID });
    const { iv, data } = resource.data;
    const iv_buf = Buffer.from(iv, 'base64');
    const enc_buf = Buffer.from(data, 'base64');

    const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv_buf);
    const decrypted = Buffer.concat([decipher.update(enc_buf), decipher.final()]);

    const outPath = './student.txt';

    fs.writeFileSync(outPath, decrypted.toString('utf8'));

    console.log('Decrypted file saved to', outPath);

}

runClient();