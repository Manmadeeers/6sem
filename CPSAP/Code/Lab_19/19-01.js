const express = require('express');
const ctrlHelper = require('./Controller-Helper');
const app = express();
const PORT = 3000;


const router = new (ctrlHelper.MVCRouter)(
    '/:controller/:action',
    '/api/controller/:action/:p',
    '/loc/lex/:controller/:m/:action'
);

const controllers = new ctrlHelper.MVCControllers(
    {
        home: {
            index: ctrlHelper.home_index,
            account: ctrlHelper.home_account
        },
        calc: {
            salary: ctrlHelper.calc_salary,
            trans: ctrlHelper.calc_trans
        }
    }
);

const mvc = new ctrlHelper.MVC(router, controllers);

app.get(mvc.router.uri_templates,mvc.use);

app.listen(PORT, () => {
    console.log(`Server listening http://localhost:${PORT}`);
});