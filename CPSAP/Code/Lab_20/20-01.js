const express = require('express');
const hbs = require('express-handlebars').create({extname:'.hbs'});
const path = require('path');
const PORT = 3000;
const app = express();


app.set(express.static(path.join(__dirname,'public')));

app.set('.hbs',hbs.engine);
app.set('view engine','.hbs');

app.get('/',(req,res)=>{
    res.render('index',{layout:null,hw:"Hello World"});
});

app.listen(PORT,()=>{
    console.log(`Server running at http://localhost:${PORT}`);
});