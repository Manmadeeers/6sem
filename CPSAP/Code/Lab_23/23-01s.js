const express = require('express');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');

const sessions = new Map();

const dhParams = crypto.createDiffieHellman(2048);
const p = dhParams.getPrime('hex');
const g = dhParams.getGenerator('hex');

const app = express();
app.use(express.json({ limit: '1mb' }));

app.get('/start', (req, res) => {
  const serverDH = crypto.createDiffieHellman(Buffer.from(p, 'hex'), Buffer.from(g, 'hex'));
  serverDH.generateKeys();
  const A_hex = serverDH.getPublicKey('hex');
  const sessionId = uuidv4();

  sessions.set(sessionId, { serverDH, step: 1, created: Date.now() });

  res.json({ p, g, A: A_hex, sessionId });
});


app.post('/finish-dh', (req, res) => {
  const { sessionId, B } = req.body || {};
  if (!sessionId || !B) {
    return res.status(409).json({ error: 'Missing sessionId or B — protocol violation' });
  }
  const session = sessions.get(sessionId);
  if (!session || session.step !== 1) {
    return res.status(409).json({ error: 'Invalid or expired session — protocol violation' });
  }

  try {
    const { serverDH } = session;

    if (typeof B !== 'string' || !B.match(/^[0-9a-fA-F]+$/)) {
      return res.status(409).json({ error: 'Invalid B format' });
    }

    const clientPub = Buffer.from(B, 'hex');
   
    const sharedSecret = serverDH.computeSecret(clientPub);
    const key = crypto.createHash('sha256').update(sharedSecret).digest(); // 32 bytes

    session.sharedKey = key;
    session.step = 2;

    res.json({ ok: true });
  } catch (e) {
    console.error('finish-dh error', e);
    return res.status(409).json({ error: 'Protocol error during key computation' });
  }
});

app.get('/resource', (req, res) => {
  const sessionId = req.query.sessionId;
  if (!sessionId) return res.status(409).json({ error: 'Missing sessionId' });
  const session = sessions.get(sessionId);
  if (!session || session.step !== 2 || !session.sharedKey) {
    return res.status(409).json({ error: 'DH not completed or invalid session' });
  }

  const key = session.sharedKey; // Buffer 32

  const studentName = 'Филипюк Илья Андреевич';
  const plain = studentName + '\n';

  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);
  const encrypted = Buffer.concat([cipher.update(Buffer.from(plain, 'utf8')), cipher.final()]);

  res.json({ iv: iv.toString('base64'), data: encrypted.toString('base64') });
});


const PORT = 3000;
app.listen(PORT, () => console.log(`Server listening on http://localhost:${PORT}`));