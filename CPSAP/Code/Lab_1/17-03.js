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
        var incrStartTime = performance.now();
        for(let i=0;i<10000;i++){
            let currentKey = "Key"+i.toString();
            await client.incr(currentKey);
        }
        var incrStopTime = performance.now();

        console.log(`10000 INCR operations took ${incrStopTime-incrStartTime} milliseconds`);

        var decrStartTime = performance.now();
        
        for(let i=0;i<10000;i++){
            let currentKey = "Key"+i.toString();
            await client.decr(currentKey);
        }
        var decrStopTime = performance.now();

        console.log(`10000 DECR operations took ${decrStopTime-decrStartTime} milliseconds`);
        await client.quit();
    }
    catch(err){
        console.error("Exception cought: ",err);
    }
})();