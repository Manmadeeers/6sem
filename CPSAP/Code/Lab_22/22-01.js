const https = require('https');
const express = require('express');
const fs = require('fs');
const path = require('path');
const PORT = 443;

const options = {
    key: fs.readFileSync(path.join(__dirname,'rs-key-fia.key')),
    cert: fs.readFileSync(path.join(__dirname,'rs-fia.crt'))
}


const server = https.createServer(options, (req,res)=>{
    if(req.method!='GET'){
        res.writeHead(405,{'content-type':'text/plain'});
        res.end("Method not allowed");
    }
    res.writeHead(200,{'content-type':'text/plain;charset-utf-8'});
    res.end(`HTTPS connection works! Request came from domen: ${req.headers.host}`);
});


server.listen(PORT,()=>{
    console.log(`Server running at https://LAB22-FIA:${PORT}`);
});