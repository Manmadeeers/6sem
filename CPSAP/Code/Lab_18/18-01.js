const express = require('express');
const seq = require('sequelize');
const ted = require('tedious');
const fs = require('fs');
const path = require('path');

const PORT = 3000;

const app = express();
const sequelize = new seq.Sequelize(
    'UNIVER',
    'sa',
    '123StrongPass!',{
        dialect:'mssql',
        host:'localhost'
    }
);


sequelize.authenticate()
.then(()=>{
    console.log("Database connaction established");

})
.catch(err=>{
    console.log("Database connection failed. ",err);
});

const orm = require('./ORM_helper').ORM(sequelize);

app.get('/', async (req, res) => {
    try {
        if (!fs.existsSync('./index.html')) {
            return res.status(500).json({ error: "Server error. index.html file does not exist" });
        }
        res.setHeader('content-type', 'text/html;charset=utf-8');
        await fs.readFile('index.html', 'utf-8', (err, data) => {
            if (err) {
                throw new Error(err);
            }
            if (data) {
                return res.status(200).send(data);
            }
        });
    }
    catch (err) {
        console.error(err);
    }

});

app.get('/api/faculties',async(req,res)=>{
    try{
        orm.Faculty.findAll()
        .then(faculties=>{return res.status(200).json(faculties)})
        .catch(err=>{return res.status(500).json({error:`Something went wrong: ${err}`})});
    }
    catch(err){
        console.error(err);
    }
});

app.get('/api/pulpits',async(req,res)=>{
    try{
        orm.Pulpit.findAll()
        .then(pulpits=>{return res.status(200).json(pulpits)})
        .catch(err=>{res.status(500).json({error:`Something went wrong: ${err}`})});
    }
    catch(err){
        console.error(err);
    }
});

app.get('/api/subjects',async(req,res)=>{
    try{
        orm.Subject.findAll()
        .then(subjects=>{return res.status(200).json(subjects)})
        .catch(err=>{return res.status(500).json({error:`Something went wrong: ${err}`})});
    }
    catch(err){
        console.error(err);
    }
});

app.get('api/auditoriumstypes',async(req,res)=>{
    try{
        orm.Auditorium_type.findAll()
        .then(auditoriumstypes=>{return res.status(200).json(auditoriumstypes)})
        .catch(err=>{return res.status(500).json({error:`Something went wrong: ${err}`})});
    }
    catch(err){
        console.error(err);
    }
});

app.get('api/auditoriums',async(req,res)=>{
    try{
        orm.Auditorium.findAll()
        .then(auditoriums=>{return res.status(200).json(auditoriums)})
        .catch(err=>{return res.status(500).json({error:`Something went wrong: ${err}`})});
    }
    catch(err){
        console.error(err);
    }
});


app.post('/api/faculties',async(req,res)=>{
    try{
        
    }
    catch(err){
        console.error(err);
    }
});


app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});