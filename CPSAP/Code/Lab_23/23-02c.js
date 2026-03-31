const axios = require('axios');
const crypto = require('crypto');
const serverURI = "http://localhost:3000";
async function run() {
    try {
        const initResult = await axios.get(`${serverURI}/init`);
        const { sessionId, publicKey } = initResult.data;
        console.log(`Session with session id ${sessionId} initialized`);

        const resourceResult = await axios.get(`${serverURI}/resource`,{params:{sessionID:sessionId}});
        const { data, signature } = resourceResult.data;
        
        if(!crypto.verify("SHA256",Buffer.from(data),publicKey,Buffer.from(signature,'base64'))){
            console.log("Verification failed!");
        }
        else{
            console.log("Verification successfull!");
        }


    }
    catch (err) {
        console.error("Error: ", err.message);
    }
}

run();  