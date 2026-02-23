const express = require('express');
const path = require('path');
const studentRoutes = require('./routes/StudentsRouter.js');

const app = express();
const PORT = 3000;

app.use(express.urlencoded({extended:true}));
app.use(express.json());

const methodOverride = require('method-override');
app.use(methodOverride('_method'));

app.set('view engine','ejs');
app.set('views',path.join(__dirname,'public'));


app.



app.listen(PORT, () => {
    console.log(`Server listening http://localhost:${PORT}`);
});