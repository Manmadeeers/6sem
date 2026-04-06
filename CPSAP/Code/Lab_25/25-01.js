const jrpc = require('json-rpc-2.0');
const express = require('express');
const bodyParser = require('body-parser');
const PORT = 3000;

const server = new jrpc.JSONRPCServer();
const app = express();
app.use(bodyParser.json());

server.addMethod("sum", (params) => {
    console.log("SUM method params: ", params);
    if (!Array.isArray(params)) {
        throw new Error("SUM method parameters must be an array");
    }
    var sum = 0;
    params.forEach(param => {
        if (typeof param != 'number') {
            throw new Error("Params must be of type number");
        }
        sum += param;
    });

    return sum;
});

server.addMethod("mul", (params) => {
    if (!Array.isArray(params)) {
        throw new Error("MUL method parameters must be an array");
    }
    var mul = 1;

    params.forEach(param => {
        if (typeof param != 'number') {
            throw new Error("Params must be of type number");
        }
        mul *= param;
    });
    return mul;
});

server.addMethod("div", ({ x, y }) => {
    if (typeof x != 'number' || typeof y != 'number') {
        throw new Error("DIV method params must be of type number");
    }

    if (y == 0) {
        throw new Error("Could not devide by 0. Change your Y parameter");
    }

    return x / y;
});

server.addMethod("proc", ({ x, y }) => {
    if (typeof x != 'number' || typeof y != 'number') {
        throw new Error("PROC method parameters must be of type number");
    }
    if (y == 0) {
        throw new Error("Could not devide by 0. Change your Y parameter");
    }
    return x / y * 100;
});


app.post('/jrpc', (req, res) => {
    const JRPCRequest = req.body;
    console.log("/jrpc body: ", JRPCRequest);

    server.receive(JRPCRequest)
        .then((JRPCRespose) => {
            if (JRPCRespose) {
                if (JRPCRespose.error) {
                    return res.status(500).json({ error: `Message: ${JRPCRespose.error.message}; Code: ${JRPCRespose.error.code}` });
                }

                return res.status(200).json({ result: JRPCRespose });
            }
            else {
                return res.status(204).json({ result: "No content" });
            }
        }).catch((err) => {
            return res.status(400).json({ error: `Bad request. Error: ${err.message}` });
        });


});


app.listen(PORT, () => {
    console.log(`Server listening on http://localhost:${PORT}`);
});