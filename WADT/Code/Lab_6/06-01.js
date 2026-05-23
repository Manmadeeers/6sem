const express = require('express');
const mssql = require('mssql');
const PORT = 3000;

const app = express();
app.use(express.json());

const dbConfig = {
    user: 'sa',
    password: '!StrongPassword_123',
    server: 'localhost',
    port:1434,
    database: 'Celebrities',
    options: {
        encrypt: true,
        trustServerCertificate: true
    }
}


async function initDB() {
    try {
        const pool = await mssql.connect(dbConfig);
        const connectionResult = await pool.query(`SELECT * FROM sys.databases WHERE name = 'Celebrities'`);

        console.log('Database check result: ', connectionResult.output);

    }
    catch (err) {
        console.error('Database init error: ', err);
    }
}

app.get('/db', async (req, res) => {
    try {
        const pool = await mssql.connect(dbConfig);
        const result = await pool.request()
            .query('Select * from Celebrities');

        if (result.recordset.length == 0) {
            res.status(204);
        }
        else {
            res.status(200).json(result.recordset);
        }
    }
    catch (err) {
        console.error('Failed to get all celebrities: ', err);
        res.status(500).json({ error: err.message });
    }
});

app.get('/db/:id', async (req, res) => {
    try {
        const pool = await mssql.connect(dbConfig);
        const result = await pool.request()
            .input('Id', mssql.Int, req.params.id)
            .query('Select * from Celebrities where Id=@Id');

        if (result.recordset.length == 0) {
            res.status(404).json({ error: 'Record not found' });
        }
        else {
            res.status(200).json(result.recordset);
        }
    }
    catch (err) {
        console.error("Failed to get a celebrity by id: ", err);
        res.status(500).json({ error: err.message });
    }
});

app.post('/db', async (req, res) => {
    try {

        const pool = await mssql.connect(dbConfig);
        const { FullName, Nationality, ReqPhotoPath } = req.body;

        await pool.request()
            .input('FullName', mssql.NVarChar, FullName)
            .input('Nationality', mssql.NVarChar, Nationality)
            .input('ReqPhotoPath', mssql.NVarChar, ReqPhotoPath)
            .query('Insert into Celebrities values (@FullName, @Nationality, @ReqPhotoPath)');
        res.status(201).json(req.body);
    }
    catch (err) {
        console.error("Failed to add a new celebrity: ", err);
        res.status(500).json({ error: err.message });
    }
});

app.put('/db/:id', async (req, res) => {
    try {
        const pool = await mssql.connect(dbConfig);
        const { FullName, Nationality, ReqPhotoPath } = req.body;

        await pool.request()
            .input('Id', mssql.Int, req.params.id)
            .input('FullName', mssql.NVarChar, FullName)
            .input('Nationality', mssql.NVarChar, Nationality)
            .input('ReqPhotoPath', mssql.NVarChar, ReqPhotoPath)
            .query('Update Celebrities set FullName=@FullName, Nationality=@Nationality, ReqPhotoPath=@ReqPhotoPath where Id=@Id');

        res.status(200).json(req.body);

    }
    catch (err) {
        console.error("Failed to update a record in Celebrities table: ", err);
        res.status(500).json({ error: err.message });
    }
});

app.delete('/db/:id', async (req, res) => {
    try {
        const pool = await mssql.connect(dbConfig);

        await pool.request()
            .input('Id', mssql.Int, req.params.id)
            .query('Delete from Celebrities where Id=@Id');

        res.status(200).json({ success: `Element with id ${req.params.id} successfully deleted` });
    }
    catch (err) {
        console.error("Failed to delete a record from Celebrities table: ", err);
        res.status(500).json({ error: err.message });
    }
});

app.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`);
    initDB();
});
