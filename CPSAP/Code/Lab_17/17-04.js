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
        var hsetStartTime = performance.now();
        for(let i=0;i<10000;i++){
            let currentKey = "Key"+i.toString();
            let currentField = "Field"+i.toString();
           await client.hSet("hSetKey",currentField,JSON.stringify(currentKey));
        }
        var hsetStopTime = performance.now();

        console.log(`10000 HSET operations took ${hsetStopTime-hsetStartTime} milliseconds`);

        var hgetStartTime = performance.now();
        for(let i=0;i<10000;i++){
            let currentField = "Field"+i.toString();
            const result = await client.hGet("hSetKey",currentField);
            if(i%1000==0){
                console.log('RESULT=',result?JSON.parse(result):null);
            }

        }
        var hgetStopTime = performance.now();

        console.log(`10000 HGET operations took ${hgetStopTime-hgetStartTime} milliseconds`);

        await client.quit();
    }
    catch(err){
        console.error("Exception cought: ",err);
    }
})();