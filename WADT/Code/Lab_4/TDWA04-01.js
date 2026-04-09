const express = require('express');
const readline = require('readline');
const DEFAULT_PORT = 3000;

const args = process.argv.slice(2);
const nickname = args[0]||'DEFAULT';
const port = args[1]||3000;

const app = express();
app.use(express.json());

const requestHandler = (req,res)=>{
    res.json({
        nick:nickname,
        method:req.method
    });
}


app.get('/A',requestHandler);
app.post('/A',requestHandler);
app.put('/A',requestHandler);
app.delete('/A',requestHandler);

app.listen(port,()=>{
    console.log(`Server running at http://localhost:${port}`);
})

