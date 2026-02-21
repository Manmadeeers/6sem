const express = require('express');
const seq = require('sequelize');
const ted = require('tedious');
const fs = require('fs');
const path = require('path');
const { readUsVarByte } = require('tedious/lib/token/helpers');

const PORT = 3000;

const app = express();
const sequelize = new seq.Sequelize(
    'UNIVER',
    'sa',
    '123StrongPass!', {
    dialect: 'mssql',
    host: 'localhost'
}
);

app.use(express.json());

const PayloadChecker = (payload, res) => {
    if (!payload || typeof (payload) != 'object') {
        return res.status(400).json({ error: "Bad request. Payload was invalid" });
    }
}

const ErrorHandler = (err, res, table, method) => {
    console.error(`${table} ${method} ERROR: `, err);
    return res.status(500).json({ error: `Internal server error: ${err}` });
}

const DeleteCodeChecker = (rawCode, res,) => {
    const code = decodeURIComponent(rawCode);
    if (!code || code.length < 2) {
        return res.status(400).json({ error: "Bad request. Faculty code was invalid" });
    }
    return code;
}


sequelize.authenticate()
    .then(() => {
        console.log("Database connaction established");

    })
    .catch(err => {
        console.log("Database connection failed. ", err);
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
        ErrorHandler(err, res, '', 'GET');
    }

});

app.get('/api/faculties', async (req, res) => {
    try {
        orm.Faculty.findAll()
            .then(faculties => { return res.status(200).json(faculties) })
            .catch(err => { throw new Error(err) });
    }
    catch (err) {
        ErrorHandler(err, res, "FACULTIES", 'GET');
    }
});

app.get('/api/pulpits', async (req, res) => {
    try {
        orm.Pulpit.findAll()
            .then(pulpits => { return res.status(200).json(pulpits) })
            .catch(err => { throw new Error(err) });
    }
    catch (err) {
        ErrorHandler(err, res, "PULPITS", 'GET');
    }
});

app.get('/api/subjects', async (req, res) => {
    try {
        orm.Subject.findAll()
            .then(subjects => { return res.status(200).json(subjects) })
            .catch(err => { throw new Error(err) });
    }
    catch (err) {
        ErrorHandler(err, res, "SUBJECTS", 'GET');
    }
});

app.get('/api/auditoriumstypes', async (req, res) => {
    try {
        orm.Auditorium_type.findAll()
            .then(auditoriumstypes => { return res.status(200).json(auditoriumstypes) })
            .catch(err => { throw new Error(err) });
    }
    catch (err) {
        ErrorHandler(err, res, "AUDITORIUM_TYPES", "GET");
    }
});

app.get('/api/auditoriums', async (req, res) => {
    try {
        orm.Auditorium.findAll()
            .then(auditoriums => { return res.status(200).json(auditoriums) })
            .catch(err => { throw new Error(err) });
    }
    catch (err) {
        ErrorHandler(err, res, "AUDITORIUM", "GET");
    }
});


app.post('/api/faculties', async (req, res) => {
    try {
        const payload = req.body;
        console.log(payload);

        PayloadChecker(payload, res);

        const { faculty, faculty_name } = payload;
        if (!faculty || typeof (faculty) != 'string' || !faculty_name || typeof (faculty_name) != 'string') {
            return res.status(400).json({ error: "Bad request. Payload fields were invalid" });
        }

        orm.Faculty.create({ faculty: faculty, faculty_name: faculty_name })
            .then(task => {
                console.log(task.dataValues);
                return res.status(201).json(task.dataValues);
            })
            .catch(err => {
                throw new Error(err);
            });
    }
    catch (err) {
        ErrorHandler(err, res, "FACULTIES", "POST");
    }
});


app.post('/api/pulpits', async (req, res) => {
    try {
        const payload = req.body;
        console.log(payload);

        PayloadChecker(payload, res);

        const { pulpit, pulpit_name, faculty } = payload;
        if (!pulpit || typeof (pulpit) != 'string' || !pulpit_name || typeof (pulpit_name) != 'string' || !faculty || typeof (faculty) != 'string') {
            return res.status(400).json({ error: "Bad request. Payload fields were invalid" });
        }


        orm.Pulpit.create({ pulpit: pulpit, pulpit_name: pulpit_name, faculty: faculty })
            .then(task => {
                console.log(task.dataValues);
                return res.status(201).json(task.dataValues);
            })
            .catch(err => {
                throw new Error(err);
            })
    }
    catch (err) {
        ErrorHandler(err, res, "PULPITS", "POST");
    }
});

app.post('/api/subjects', async (req, res) => {
    try {
        const payload = req.body;

        PayloadChecker(payload, res);

        const { subject, subject_name, pulpit } = payload;

        if (!subject || typeof (subject) != 'string' || !subject_name || typeof (subject_name) != 'string' || !pulpit || typeof (pulpit) != 'string') {
            return res.status(400).json({ error: "Bad request. Payload fields were invalid" });
        }

        orm.Subject.create({ subject: subject, subject_name: subject_name, pulpit: pulpit })
            .then(task => {
                console.log(task.dataValues);
                return res.status(201).json(task.dataValues);
            })
            .catch(err => {
                throw new Error(err);
            });
    }
    catch (err) {
        ErrorHandler(err, res, "SUBJECTS", "POST");
    }
});

app.post('/api/auditoriumstypes', async (req, res) => {
    try {
        const payload = req.body;

        PayloadChecker(payload, res);

        const { auditorium_type, auditorium_type_name } = payload;
        if (!auditorium_type || typeof (auditorium_type) != 'string' || !auditorium_type_name || typeof (auditorium_type_name) != 'string') {
            return res.status(400).json({ error: "Bad request. Payload fields were invalid" });
        }

        orm.Auditorium_type.create({ auditorium_type: auditorium_type, auditorium_type_name: auditorium_type_name })
            .then(task => {
                console.log(task.dataValues);
                return res.status(201).json(task.dataValues);
            })
            .catch(err => {
                throw new Error(err);
            });
    }
    catch (err) {
        ErrorHandler(err, res, "AUDITORIUMS_TYPES", "POST");
    }
});


app.post('/api/auditoriums', async (req, res) => {
    try {
        const payload = req.body;
        console.log(payload);

        PayloadChecker(payload, res);

        const { auditorium, auditorium_name, auditorium_capacity, auditorium_type } = payload;
        if (!auditorium || typeof (auditorium) != 'string' || !auditorium_name || typeof (auditorium_name) != 'string' || !auditorium_capacity || typeof (auditorium_capacity) != 'number' || !auditorium_type || typeof (auditorium_type) != 'string') {
            return res.status(400).json({ error: "Bad request. Payload fields were invalid" });
        }

        orm.Auditorium.create({ auditorium: auditorium, auditorium_name: auditorium_name, auditorium_capacity: auditorium_capacity, auditorium_type: auditorium_type })
            .then(task => {
                console.log(task.dataValues);
                return res.status(201).json(task.dataValues);
            })
            .catch(err => {
                throw new Error(err);
            });
    }
    catch (err) {
        ErrorHandler(err, res, "AUDITORIUM", "POST");
    }
});

app.put('/api/faculties', async (req, res) => {
    try {
        const payload = req.body;

        PayloadChecker(payload, res);

        const { faculty, faculty_name } = payload;
        if (!faculty || typeof (faculty) != 'string' || !faculty_name || typeof (faculty_name) != 'string') {
            return res.status(400).json({ error: "Bad request. Payload fields were invalid" });
        }

        await orm.Faculty.update(
            { faculty_name: faculty_name },
            { where: { faculty: faculty } }
        )
            .then(task => {
                console.log("Result: ", task);
                return res.status(200).json({ result: `Operation succeeded with code ${task}` });
            })
            .catch(err => {
                throw new Error(err);
            });
    }
    catch (err) {
        ErrorHandler(err, res, "FACULTIES", "PUT");
    }
});

app.put('/api/pulpits', async (req, res) => {
    try {
        const payload = req.body;

        PayloadChecker(payload, res);

        const { pulpit, pulpit_name, faculty } = payload;
        if (!pulpit || typeof (pulpit) != 'string' || !pulpit_name || typeof (pulpit_name) != 'string' || !faculty || typeof (faculty) != 'string') {
            return res.status(400).json({ error: "Bad request. Payload fields were invalid" });
        }

        await orm.Pulpit.update(
            { pulpit_name: pulpit_name, faculty: faculty },
            { where: { pulpit: pulpit } }
        )
            .then(task => {
                console.log("Result: ", task);
                return res.status(200).json({ result: `Operation succeded with code ${task}` });
            })
            .catch(err => {
                throw new Error(err);
            });
    }
    catch (err) {
        ErrorHandler(err, res, "PULPITS", "PUT");
    }

});


app.put('/api/subjects', async (req, res) => {
    try {
        const payload = req.body;

        PayloadChecker(payload, res);

        const { subject, subject_name, pulpit } = payload;
        if (!subject || typeof (subject) != 'string' || !subject_name || typeof (subject_name) != 'string' || !pulpit || typeof (pulpit) != 'string') {
            return res.status(400).json({ error: "Bad request. Payload fields were invalid" });
        }

        await orm.Subject.update(
            { subject_name: subject_name, pulpit: pulpit },
            { where: { subject: subject } }
        )
            .then(task => {
                console.log("Result: ", task);

                orm.Subject.findAll({
                    where: { subject: subject }
                })
                    .then(result => {
                        console.log("Data result: ", result);
                        return res.status(200).json(result);
                    })
                    .catch(err => {
                        throw new Error(err);
                    });

            })
            .catch(err => {
                throw new Error(err);
            });
    }
    catch (err) {
        ErrorHandler(err, res, "SUBJECTS", "PUT");
    }
});

app.put('/api/auditoriumstypes', async (req, res) => {
    try {
        const payload = req.body;

        PayloadChecker(payload, res);

        const { auditorium_type, auditorium_type_name } = payload;
        if (!auditorium_type || typeof (auditorium_type) != 'string' || !auditorium_type_name || typeof (auditorium_type_name) != 'string') {
            return res.status(400).json({ error: "Bad request. Payload fields were invalid" });
        }

        await orm.Auditorium_type.update(
            { auditorium_type_name: auditorium_type_name },
            { where: { auditorium_type: auditorium_type } }
        )
            .then(task => {
                console.log("Result: ", task);

                orm.Auditorium_type.findAll({
                    where: { auditorium_type: auditorium_type }
                })
                    .then(result => {
                        console.log("Data result: ", result);
                        return res.status(200).json(result);
                    })
                    .catch(err => {
                        throw new Error(err);
                    });
            })
            .catch(err => {
                throw new Error(err);
            });
    }
    catch (err) {
        ErrorHandler(err, res, "AUDITORIUMS_TYPES", "PUT");
    }
});

app.put('/api/auditoriums', async (req, res) => {
    try {
        const payload = req.body;

        PayloadChecker(payload, res);

        const { auditorium, auditorium_name, auditorium_capacity, auditorium_type } = payload;

        await orm.Auditorium.update(
            { auditorium_name, auditorium_capacity, auditorium_type },
            { where: { auditorium: auditorium } }
        )
            .then(task => {
                console.log("Result: ", task);
                orm.Auditorium.findAll({
                    where: { auditorium: auditorium }
                })
                    .then(result => {
                        return res.status(200).json(result);
                    })
                    .catch(err => {
                        throw new Error(err);
                    });
            })
            .catch(err => {
                throw new Error(err);
            });
    }
    catch (err) {
        ErrorHandler(err, res, "AUDITORIUMS", "PUT");
    }
});

app.delete('/api/faculties/:code', async (req, res) => {
    try {
        let code = DeleteCodeChecker(req.params.code, res);

        await orm.Faculty.findAll({
            where: { faculty: code }
        })
            .then(result => {
                console.log("Deleting: ", result)
                if (result.length < 1) {
                    return res.status(404).send({ error: `Could not find faculty with code ${code}` });
                }

                orm.Faculty.destroy({
                    where: { faculty: code }
                })
                    .then(task => {
                        console.log("Deletions result: ", res);
                        return res.status(200).json({
                            result: task,
                            payload: result
                        });
                    })
                    .catch(err => {
                        throw new Error(err);
                    })
            })
            .catch(err => {
                throw new Error(err);
            });


    }
    catch (err) {
        ErrorHandler(err, res, "FACULTY", "DELETE");
    }
});


app.delete('/api/pulpits/:code', async (req, res) => {
    try {
        let code = DeleteCodeChecker(req.params.code);

        await orm.Pulpit.findAll({
            where:{pulpit:code}
        })
        .then(result=>{
            console.log("Deleting: ",result);
            if(result.length<1){
                return res.status(404).json({error:`Could not find PULPIT with code ${code}`});
            }

            orm.Pulpit.destroy({
                where:{pulpit:code}
            })
            .then(task=>{
                console.log("Deletion result: ",task);
                return res.status(200).json({
                    result:task,
                    payload:result
                });
            })
            .catch(err=>{
                throw new Error(err);
            })
        })
        .catch(err=>{
            throw new Error(err);
        })
    }
    catch (err) {
        ErrorHandler(err, res, "PULPIT", "DELETE");
    }
});

app.delete('/api/subject/:code',async(req,res)=>{
    try{
        let code = DeleteCodeChecker(req.params.code,res);

        await orm.Subject.findAll({
            where:{subject:code}
        })
        .then(result=>{
            console.log("Deleting: ",result)
            if(result.length<1){
                return res.status(404).json({error:`Could not find SUBJECT with code ${code}`});
            }

            orm.Subject.destroy({
                where:{subject:code}
            })
            .then(task=>{
                console.log("Deletion result: ",task);
                return res.status(200).json({
                    result:task,
                    payload:result
                });
            })
            .catch(err=>{
                throw new Error(err);
            })
        })
        .catch(err=>{
            throw new Error(err);
        })
    }
    catch(err){
        ErrorHandler(err,res,"SUBJECT","DELETE");
    }
});


app.delete('/api/auditoriumstypes/:code',async(req,res)=>{
    try{
        let code =DeleteCodeChecker(req.params.code,res);

        await orm.Auditorium_type.findAll({
            where:{auditorium_type:code}
        })
        .then(result=>{
            console.log("Deleting: ",result);
            if(result.length<1){
                return res.status(404).json({error:`Could not find Audotorium type with code ${code}`});
            }

            orm.Auditorium_type.destroy({
                where:{auditorium_type:code}
            })
            .then(task=>{
                console.log("Deletion result: ",task);
                return res.status(200).json({
                    result:task,
                    payload:result
                });
            })
            .catch(err=>{
                throw new Error(err);
            })
        })
        .catch(err=>{
            throw new Error(err);
        })
    }
    catch(err){
        ErrorHandler(err,res,"AUDITORIUMS_TYPES","DELETE");
    }
})

app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});