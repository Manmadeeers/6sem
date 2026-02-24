const express = require('express');
const path = require('path');
const methodOverride = require('method-override');
const studentRoutes = require('./routes/StudentsRouter.js');

const app = express();
const PORT = 3000;

app.use(express.urlencoded({extended:true}));
app.use(express.json());


app.use(methodOverride('_method'));

app.set('view engine','ejs');
app.set('view','./views');


app.use(express.static(path.join(__dirname,'public/css')));
app.use('/students',studentRoutes);

app.get('/test',(req,res)=>{res.send("OK")});

app.listen(PORT, () => {
    console.log(`Server listening http://localhost:${PORT}`);
});