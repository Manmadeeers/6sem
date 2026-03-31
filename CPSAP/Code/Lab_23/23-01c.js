const axios = require('axios');
const crypto = require('crypto');
const fs = require('fs');

async function run() {
  try {

    const start = await axios.get('http://localhost:3000/start');
    const { p, g, A, sessionId } = start.data;
    console.log('Received DH params. sessionId=', sessionId);

    const clientDH = crypto.createDiffieHellman(Buffer.from(p, 'hex'), Buffer.from(g, 'hex'));
    clientDH.generateKeys();
    const B_hex = clientDH.getPublicKey('hex');


    await axios.post('http://localhost:3000/finish-dh', { sessionId, B: B_hex });
    console.log('Sent B to server');


    const serverPub = Buffer.from(A, 'hex');
    const sharedSecret = clientDH.computeSecret(serverPub);
    const key = crypto.createHash('sha256').update(sharedSecret).digest();


    const resource = await axios.get('http://localhost:3000/resource', { params: { sessionId } });
    const { iv, data } = resource.data;
    const iv_buf = Buffer.from(iv, 'base64');
    const enc_buf = Buffer.from(data, 'base64');


    const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv_buf);
    const decrypted = Buffer.concat([decipher.update(enc_buf), decipher.final()]);

    const outPath = './student.txt';
    fs.writeFileSync(outPath, decrypted.toString('utf8'));
    console.log('Decrypted file saved to', outPath);
  } catch (err) {
    if (err.response) {
      console.error('Server responded with', err.response.status, err.response.data);
    } else {
      console.error('Error', err.message);
    }
  }
}

run();