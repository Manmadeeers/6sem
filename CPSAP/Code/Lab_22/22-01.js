const https = require('https');
const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();

const options = {
    key:fs.readFileSync(path.join(__dirname,'LAB.key')).toString(),
    cert:
}