const BASE = 'http://localhost:32772/api/Save-JSON'


async function clickGET() {
    const resultElement = document.querySelector('.result-get');
    resultElement.textContent = '';

    try {
        const res = await fetch(BASE, { method: 'GET' });
        if (!res.ok) {
            const errBody = await res.json();
            resultElement.textContent = JSON.stringify(errBody);
            console.log("GET response not OK: ", errBody);
        }
        else {
            const data = await res.json();
            resultElement.textContent = JSON.stringify(data, null, 2);
            console.log("GET response OK: ", data);
        }
        return;
    }
    catch (err) {

    }
}

async function clickPOST() {
    const inputElement = document.querySelector('.input-post');
    const resultElement = document.querySelector('.result-post');
    resultElement.textContent = '';

    try {
        const body = JSON.parse(inputElement.value);
        const res = await fetch(BASE, {
            method: 'POST',
            headers: {
                'Content-type': 'application/json'
            },
            body: JSON.stringify(body)
        });

        if (!res.ok) {
            const errBody = await res.json();
            resultElement.textContent = JSON.stringify(errBody);
            console.log("POST response not OK: ", errBody);
        }
        else {
            const data = await res.json();
            resultElement.textContent = JSON.stringify(data, null, 2);
            console.log("POST response OK: ", data);
        }
        return;
    }
    catch (err) {
        resultElement.textContent = err;
    }

}

async function clickPUT() {
    const inputElement = document.querySelector('.input-put');
    const resultElement = document.querySelector('.result-put');
    resultElement.textContent = '';
    try {
        const body = JSON.parse(inputElement.value);
        const res = await fetch(BASE, {
            method: 'PUT',
            headers: {
                'Content-type': 'application/json'
            },
            body: JSON.stringify(body)
        });

        if (!res.ok) {
            const errBody = await res.json();
            resultElement.textContent = JSON.stringify(errBody);
            console.log("PUT response not OK: ", errBody);
        }
        else {
            const data = await res.json();
            resultElement.textContent = JSON.stringify(data, null, 2);
            console.log("PUT response OK: ", data);
        }
        return;
    }
    catch (err) {
        resultElement.textContent = err;
    }
}

async function clickDELETE() {
    const resultElement = document.querySelector('.result-delete');
    resultElement.textContent = '';

    try {
        const res = await fetch(BASE,{method:'DELETE'});
        if(!res.ok){
            const errBody =await res.json();
            resultElement.textContent = JSON.stringify(errBody);
            console.log("DELETE response not OK: ",errBody);
        }
        else{
            const data = res.body;
            resultElement.textContent = JSON.stringify(data,null,2);
            console.log("DELETE response OK: ",data);
        }
        return;
    }
    catch (err) {
        resultElement.textContent = err;
    }
}