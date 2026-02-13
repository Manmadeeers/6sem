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


app.get('/NGINX-test',async(req,res)=>{
    try{
    }
    catch(err){
       if(err.code=='ENOENT'){
            return res.status(404).json({error:'Reqest not found on server'});
       }
       console.error(err);
       return res.status(500).json({error:"Internal server error"});
    }
});




app.listen(PORT,()=>{
    console.log(`Server listening on http://localhost:${PORT}`);
})