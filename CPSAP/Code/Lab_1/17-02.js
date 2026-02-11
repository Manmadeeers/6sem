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

        var setStartTime = performance.now();
        for(let i=0;i<10000;i++){
            let currentKey = "Key"+i.toString();
            await client.set(currentKey,i.toString());
        }
        var setStopTime = performance.now();

        console.log(`10000 SET operations took ${setStopTime-setStartTime} milliseconds`);


        var getStartTime = performance.now();

        for(let i=0;i<10000;i++){
            let currentKey = "Key"+i.toString();
           const result = await client.get(currentKey);
           if(i%1000==0){
                console.log('RESULT=',result?result:null);
           }
        }
        var getStopTime = performance.now();

        console.log(`10000 GET operations took ${getStopTime-getStartTime} milliseconds`);

        var delStartTime = performance.now();

        for(let i=0;i<10000;i++){
            let currentKey = "Key"+i.toString();
            await client.del(currentKey);
        }

        var delStopTime = performance.now();

        console.log(`10000 DEL operations took ${delStopTime-delStartTime} milliseconds`);

        await client.quit();
    }
    catch(err){
        console.error('Exception cought: ',err);
    }
})();