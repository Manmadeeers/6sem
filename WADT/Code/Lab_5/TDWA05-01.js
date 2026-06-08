const express = require('express');

const args = process.argv.slice(2, 5);
const NICKNAME = args[0] || 'DEFAULT';
const PORT = Number(args[1]) || 3000;
const DELAY = Number(args[2]) || 3000;

const app = express();
app.use(express.json());


const requestHandler = function (req, res) {
    res.json({
        nick: NICKNAME,
        method: req.method
    });
};

const withDelay = (timeout) => (req, res) => {
    setTimeout(() => requestHandler(req, res), timeout);
};

app.get('/A', withDelay(DELAY / 3));
app.post('/A', withDelay((DELAY * 2) / 3));
app.put('/A', withDelay(DELAY));
app.delete('/A', withDelay(DELAY / 4));


app.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`);
    console.log(`Server parameters:\nNICKNAME:${NICKNAME}\nPORT:${PORT}\nDELAY:${DELAY}`);
});
