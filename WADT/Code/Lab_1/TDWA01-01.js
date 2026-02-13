const express = require('express');
const fs = require('fs');
const path = require('path');
const app = express();
const PORT = 40000;
const JSON_BUFFER = {};


function compute(op,x,y){
    switch((op||'').toLowerCase()){
        case 'add':
            return x+y;
        case 'sub':
            return x-y;
        case 'mul':
            return x*y;
        case 'div':
            if(y==0){
                throw new Error("Division by zero");
            }
            return x/y;
        default:
            throw new Error("Unsupported operation");
    }
}


app.use(express.json());


app.get('/NGINX-test',async(req,res)=>{
    try{
        if(Object.keys(JSON_BUFFER).length==0){
            return res.status(404).json({error:"Request not found on server"});
        }

        let result = {op:JSON_BUFFER.op,x:JSON_BUFFER.x,y:JSON_BUFFER.y,result:compute(JSON_BUFFER.op,JSON_BUFFER.x,JSON_BUFFER.y)};
        
        res.setHeader('content-type','application/json');
        return res.status(200).json(result);


    }
    catch(err){
       console.error(err);
       return res.status(500).json({error:"Internal server error"});
    }
});


app.post('/NGINX-test',(req,res)=>{
    try{
        if(Object.keys(JSON_BUFFER)!=0){
            return res.status(409).json({error:"JSON request already present on server"});
        }

        const payload = req.body;
        
        if(!payload||typeof(payload)!='object'){
            return res.status(400).json({error:"Payload was empty or of an invalid format"});
        }
        if(typeof(payload.op)!='string'||typeof(payload.x)!='number'||typeof(payload.y)!='number'){
            return res.status(400).json({error:"Invalid request fields"});
        }

        Object.assign(JSON_BUFFER,payload);
        console.log("JSON_BUFFER after POST: ",JSON_BUFFER);
        res.setHeader('content-type','application/json');
        return res.status(200).json(JSON_BUFFER);


    }
    catch(err){
        console.error(err);
        return res.status(500).json({error:"Internal server error"});
    }
});

app.put('/NGINX-test',(req,res)=>{
    try{
        if(Object.keys(JSON_BUFFER).length==0){
            return res.status(404).json({error:"Request not fond on server"});
        }

        const payload = req.body;
        console.log("JSON_BUFFER before PUT: ",JSON_BUFFER);

        if(!payload||typeof(payload)!='object'){
            return res.status(400).json({error:"Payload was empty or of an invalid format"});
        }

        const {op,x,y} = payload;
        if(typeof(op)!='string'||typeof(x)!='number'||typeof(y)!='number'){
            return res.status(400).json({error:"Payload fields were of an invalid format"});
        }

        Object.assign(JSON_BUFFER,payload);

        console.log("JSON_BUFFER after PUT: ",JSON_BUFFER);

        res.setHeader('content-type','application/json');
        return res.status(200).json(JSON_BUFFER);
    }
    catch(err){
        return res.status(500).json({error:"Internal server error: ",err});
    }
});

app.delete('/NGINX-test',(req,res)=>{
    try{
        if(Object.keys(JSON_BUFFER).length==0){
            return res.status(404).json({error:"Response not found on server"});
        }
        
        delete JSON_BUFFER.op;
        delete JSON_BUFFER.x;
        delete JSON_BUFFER.y;
        console.log("JSON_BUFFER after DELETE: ",JSON_BUFFER);

        return res.status(200).end();
    }
    catch(err){
        console.error(err);
        return res.status(500).json({error:"Internal server error: ",err});
    }
})




app.listen(PORT,()=>{
    console.log(`Server listening on http://localhost:${PORT}`);
});