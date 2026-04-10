const express = require('express');

const args = process.argv.slice(2, 5);
const NICKNAME = args[0] || 'DEFAULT';
const PORT = args[1] || 3000;
const DELAY = args[2] || 3000;

const app = express();
app.use(express.json());


const requestHandler = function (req, res) {
    res.json({
        nick: NICKNAME,
        method: req.method
    });
}


app.get('/A', (req, res) => setTimeout(requestHandler(req, res), DELAY / 3));
app.post('/A', (req, res) => setTimeout(requestHandler(req, res), DELAY * 2 / 3));
app.put('/A', (req, res) => setTimeout(requestHandler(req, res), DELAY));
app.delete('/A', (req, res) => setTimeout(requestHandler(req, res), DELAY / 4));


app.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`);
    console.log(`Server parameters:\nNICKNAME:${NICKNAME}\nPORT:${PORT}\nDELAY:${DELAY}`);
});