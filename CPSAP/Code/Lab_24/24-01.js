const express = require('express');
const readline = require('readline');
const webdav = require('webdav');
const path = require('path');
const { endianness } = require('os');
const PORT = 3000;

let wdClient = webdav.createClient();

const app = express();
app.use(express.raw({ type: '*/*', limit: '100mb' }));

async function promptPassAndInit() {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question("Eneter the disk password: ", (password) => {
        rl.close();

        wdClient = webdav.createClient(
            "https://webdav.yandex.ru",
            {
                username: 'Iliafilipiuk',
                password: password
            }
        );


        app.listen(PORT, () => {
            console.log(`Server listening on http://localhost:${PORT}`);
        });

    });
}


async function deletionHelper(dirName) {
    const items = await wdClient.getDirectoryContents(dirName);

    for (const item of items) {
        const itemPath = item.filename;

        if (item.type === 'directory') {
            await deletionHelper(dirName);
        }
        else {
            await wdClient.deleteFile(itemPath);
        }
    }

    await wdClient.deleteFile(dirName);
}


app.post('/md/:name', async (req, res) => {
    const dirName = req.params.name;
    const relativePath = `/${dirName}`;

    try {
        if (await wdClient.exists(relativePath)) {
            return res.status(408).json({ error: "Directory already exists" });
        }

        await wdClient.createDirectory(relativePath);
        return res.status(201).json({ created: `Directory with name ${relativePath} created` });
    }
    catch (err) {
        console.log("POST /md/name error: ", err.message);
        return res.status(500).json({ error: `Internal server error: ${err.message}` });
    }
});

app.post('/rd/:name', async (req, res) => {
    const dirName = req.params.name;
    const relativePath = `/${dirName}`;

    try {
        if (!await wdClient.exists(relativePath)) {
            return res.status(408).json({ error: "Directory does not exists" });
        }

        await deletionHelper(relativePath);
        return res.status(200).json({ deleted: `Directory named ${dirName} and it's contents successfully deleted` });
    }
    catch (err) {
        console.error(`POST /rd/name error: `, err.message);
        return res.status(500).json({ error: `Internal server error: ${err.message}` });
    }
});


app.post('/up/:fileName', async (req, res) => {
    const fileName = req.params.fileName;
    const relFilePath = `/${fileName}`;

    const contents = req.body;
    if (!contents || contents.length == 0) {
        return res.status(400).json({ error: "Bad request. Request body is absent or of zero length" });
    }

    try {

        if (!await wdClient.putFileContents(relFilePath, contents, { overwrite: true })) {
            return res.status(408).json({ error: "Unable to write file or it's contents" });
        }
        return res.status(201).json({ created: `File named ${fileName} was successfully created` });
    }
    catch (err) {
        console.error("POST /up/fileName error: ", err.message);
        return res.status(408).json({ error: `Internal server error: ${err.message}` });
    }
});


app.post('/down/:fileName', async (req, res) => {
    const relFilePath = `/${req.params.fileName}`;

    try {
        if (!await wdClient.exists(relFilePath)) {
            return res.status(404).json({ error: 'Could not filed a file with a specified name' });
        }

        const fileContents = await wdClient.getFileContents(relFilePath);
        if(!fileContents||fileContents.length==0){
            return res.status(500).json({error:"Unable to download a specified file due to invalid contents"});
        }

        res.setHeader('Content-type','application/octet-stream');
        res.setHeader('Content-disposition',`attachment; filename=${path.basename(relFilePath)}`);
        res.status(200).send(fileContents);

    }
    catch (err) {
        console.error("POST /down/fileName error: ", err.message);
        return res.status(500).json({ error: `Internal server error: ${err.message}` });
    }

});


app.post('/del/:fileName',async (req,res)=>{
    const relFilePath = `/${req.params.fileName}`;

    try{
        if(!await wdClient.exists(relFilePath)){
            return res.status(404).json({error:"File not found. Could not delete"});
        }
        await wdClient.deleteFile(relFilePath);
        return res.status(200).json({delete:`File named ${relFilePath} deleted successfully`});
    }
    catch(err){
        console.error("POST /del/:fileName error: ",err.message);
        return res.status(500).json({error:`Internal server error: ${err.message}`});
    }
});

app.post('/copy/:srcName/:destName',async (req,res)=>{
    const srcRelFilePath = `/${req.params.srcName}`;
    const destRelFilePath = `/${req.params.destName}`;

    try{
        if(!await wdClient.exists(srcRelFilePath)){
            return res.status(404).json({error:"File not found. Could not copy"});
        }

        await wdClient.copyFile(srcRelFilePath,destRelFilePath);
        return res.status(200).json({copy:`File copied successfully from ${srcRelFilePath} to ${destRelFilePath}`});
    }
    catch(err){
        console.error("POST /copy/... error: ",err.message);
        return res.status(500).json({error:`Internal server error: ${err.message}`});
    }
});


app.post('/move/:srcName/:destName',async (req,res)=>{
    const srcRelFilePath = `/${req.params.srcName}`;
    const destRelFilePath = `/${req.params.destName}`;

    try{
        if(!await wdClient.exists(srcRelFilePath)){
            return res.status(404).json({error:"File not found. Could not move"});
        }
        await wdClient.moveFile(srcRelFilePath,destRelFilePath);
        return res.status(301).json({move:`File moved successfully from ${srcRelFilePath} to ${destRelFilePath}`});
    }
    catch(err){
        console.error("POST /move/... error: ",err.message);
        return res.status(500).json({error:`Internal server error: ${err.message}`});
    }
})


promptPassAndInit();