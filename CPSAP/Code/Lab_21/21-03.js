const express = require('express');
const session = require('express-session');
const bodyParser = require('body-parser');
const fs = require('fs');
const path = require('path');
const creds = require('./credentials.json');
const PORT = 3000;

function findUser(login) {
    return creds.users.find(u => u.login == login) || null;
}

const app = express();

app.use(bodyParser.urlencoded({ extended: false }));
app.use(bodyParser.json());

app.use(express.static(path.join(__dirname, 'public')));

app.use(session({
    secret: 'koi carp',
    resave: false,
    saveUninitialized: false
}));


const formAuthMiddleware = (req,res,next)=>{
    const {login,password} = req.body;

    const user = findUser(login);
    if(!user||user.password!=password){
        return res.redirect('/login');
    }

    req.session.user = user;

    next();
}

app.get('/login',(req,res)=>{
    const resBody = fs.readFileSync(path.join(__dirname,'views','login.html'));
    if(!resBody){
        res.status(500).json({error:"Internal server error. Failed to load login page"});
    }
    else{
        res.header('Content-type','text/html');
        res.send(resBody);
    }
});

app.post('/login',formAuthMiddleware,(req,res)=>{
    res.redirect('/resource');
});

app.get('/resource',(req,res)=>{
    if(!req.session.user){
        return res.redirect('/login');
    }
    const resBody = fs.readFileSync(path.join(__dirname,'views','resource.html'));
    if(!resBody){
        res.status(500).json({error:"Internal server error. Failed to load resource page"});
    }
    else{
        res.header('Content-type','text/html');
        res.send(resBody);
    }
});

app.get('/logout',(req,res)=>{
    req.session.destroy(()=>{
        const resBody = fs.readFileSync(path.join(__dirname,'views','logout.html'));
        if(!resBody){
            res.status(500).json({error:"Internal server error. Failed to load logout page"});
        }
        else{
            res.header('Content-type','text/html');
            res.send(resBody);
        }
    })
});

app.use((req, res) => {
    res.status(404).json({ error: "Not found. Resource with corresponding URI could not be found" });
});

app.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}/login`);
});