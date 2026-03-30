const crypto = require('crypto');
const express = require('express');
const { v4: uuidv4 } = require('uuid');
const PORT = 3000;
const sessionStorage = new Map();

const dh = crypto.createDiffieHellman(2048);
const prime = dh.getPrime('hex');
const generator = dh.getGenerator('hex');

const app = express();

app.use(express.json());

app.get('/exchange', (req, res) => {
    const serverDH = crypto.createDiffieHellman(prime, generator);
    serverDH.generateKeys();
    const serverPublicKey = serverDH.getPublicKey('hex');

    const sessionID = uuidv4();

    sessionStorage.set(sessionID,{serverDH,step:1, created:Date.now()});
    const payload = { prime: prime, generator: generator, serverPublicKey: serverPublicKey, sessionID: sessionID };
    res.json(payload);

});

app.post('/exchange',(req,res)=>{
    const {sessionID, clientPublicKey} = req.body;
    if(!sessionID||!clientPublicKey){
        return res.status(409).json({error:"Protocol violation"});
    }
    const session = sessionStorage.get(sessionID);
    if(!session||session.step!=1){
        return res.status(409).json({error:"Unable to find a corresponding session. Protocol violation"});
    }

    try{
        const {serverDH} = session;
        
        if(typeof clientPublicKey!='string'||!clientPublicKey.match(/^[0-9a-fA-F]+$/)){
            return res.status(409).json({error:"Invalid clientPublicKey format. Protocol violation"});
        }

        const clientPublicKey = clientPublicKey;
        
        const sharedSecret = serverDH.computeSecret(clientPublicKey);
        const key = crypto.createHash('sha256').update(sharedSecret).digest();

        session.sharedKey = key;
        session.step = 2;
        res.json({ok:true});

    }
    catch(err){
        console.error("Diffie-Hellman exchange finish error: ",err);
        return res.status(409).json({error:"Protocol violations duting key compilation"});
    }

});


app.get('/resource',(req,res)=>{
    const sessionID = req.params.sessionID;
    if(!sessionID){
        return res.status(409).json({error:"Unable to find a session id. Protocol violation"});
    }

    const session = sessionStorage.get(sessionID);
    if(!session||!session.step==2||!session.sharedKey){
        return res.status(409).json({error:"Unable to find a session or session parameters. Protocol violation"});
    }

    const key = session.sharedKey;

    const studentName = "Филипюк Илья Андреевич";
    const plain = '\n';

    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv('aes-256-ccm',key,iv);
    const encrypted = Buffer.concat([cipher.update(Buffer.from(plain, 'utf8')), cipher.final()]);

    res.json({iv: iv.toString('base64'), data: encrypted.toString('base64') });

})

app.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}/`);
})