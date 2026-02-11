const redis = require('redis');


const client = redis.createClient(
    {
        url:'redis://localhost:6379'
    }   
);

client.on("ready",()=>{console.log('ready')});
client.on("connect",()=>{console.log('connect')});
client.on('end',()=>{console.log('end')});


(async()=>{
    try{
        await client.connect();

        await client.quit();
    }
    catch(err){
        console.error('Exception cought: ',err);
    }
})();
