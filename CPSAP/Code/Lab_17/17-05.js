const { resolve } = require('path');
const redis = require('redis');
const PUBLISH_DURATION=5000;
const PUBLISH_INTERVAL=500;
const clientP = redis.createClient(
    {
         url:'redis://localhost:6379'
    }
);
const clientS = clientP.duplicate();

clientS.on('error',(err)=>{console.error("Subscriber failed: ",err)});



clientP.on("ready",()=>{console.log('publisher ready')});
clientP.on("connect",()=>{console.log('publisher connected')});
clientP.on('end',()=>{console.log('publisher end')});

clientS.on('ready',()=>{console.log("subsciber ready")});
clientS.on('connect',()=>{console.log("subscriber connected")});
clientS.on('end',()=>{console.log("subscriber end")});
clientS.on('subscribe',(channel,count)=>{console.log(`Subscriber subscribed to channel ${channel}. Count=${count}`);});
clientS.on('unsubscribe',()=>{console.log('Suscriber unsubscribed from all channels');});

function sleep(ms){
    return new Promise(resolve=>setTimeout(resolve,ms));
}

async function PublishMessages(messageCounter){
    let iterations = Math.floor(PUBLISH_DURATION/PUBLISH_INTERVAL);
    for(let i=0;i<iterations;i++){
        await clientP.publish('channel',`Message ${messageCounter++}`);

        await sleep(PUBLISH_INTERVAL);
    }
   
}


(async()=>{
    try{
        let messageCounter = 0;
        const listener = (message,channel)=>{console.log(`Message ${message} read from channel ${channel}`);}
        await clientP.connect();
        await clientS.connect();

        await clientS.subscribe('channel',listener);

        await PublishMessages(messageCounter);

        await clientS.unsubscribe();
        await clientS.quit();

        await clientP.quit();
    }
    catch(err){
        console.error('Exception cought: ',err);
    }
})();