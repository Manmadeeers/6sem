import React, { useState } from "react";


const BASE = 'http://localhost:32768/api/Save-JSON';


function App() {
  const [postInput, setPostInput] = useState('');
  const [putInput, setPutInput] = useState('');

  const [getResult, setGetResult] = useState('');
  const [postResult, setPostResult] = useState('');
  const [putResult, setPutResult] = useState('');
  const [deleteResult, setDeleteResult] = useState('');

  function prettifyJSON(data) {
    try {
      return typeof (data) === 'string' ? data : JSON.stringify(data, null, 2);
    }
    catch {
      return String(data);
    }
  }

  async function clickGET() {
    setGetResult('');
    try {
      const res = await fetch(BASE, { method: 'GET' });
      if (!res.ok) {
        const errBody = await res.json();
        setGetResult(prettifyJSON(errBody));
        console.log("GET response not OK: ", errBody);
      }
      else {
        const data = await res.json();
        setGetResult(prettifyJSON(data));
        console.log("GET response OK: ", data);
      }
    }
    catch (err) {
      setGetResult(String(err));
    }
  }

  async function clickPOST() {
    setPostResult('');
    try {
      const body = JSON.parse(postInput || '{}');
      const res = await fetch(BASE, {
        method: 'POST',
        headers: { 'Content-type': 'application/json' },
        body: JSON.stringify(body)
      });

      if (!res.ok) {
        const errBody = await res.json();
        setPostResult(prettifyJSON(errBody));
        console.log("POST response not OK: ", errBody);
      }
      else {
        const data = await res.json();
        setPostResult(prettifyJSON(data));
        console.log("POST response OK: ", data);
      }
    }
    catch (err) {
      setPostResult(String(err));
    }
  }

  async function clickPUT() {
    setPutResult('');
    try {
      const body = JSON.parse(putInput || '{}');
      const res = await fetch(BASE, {
        method: 'PUT',
        headers: { 'Content-type': 'application/json' },
        body: JSON.stringify(body)
      });

      if (!res.ok) {
        const errBody = await res.json();
        setPutResult(prettifyJSON(errBody));
        console.log("PUT response not OK: ", errBody);
      }
      else {
        const data = await res.json();
        setPutResult(prettifyJSON(data));
        console.log("PUT response OK: ", data);
      }
    }
    catch (err) {
      setPutResult(String(err));
    }
  }

  async function clickDELETE() {
    setDeleteResult('');
    try {
      const res = await fetch(BASE, { method: 'DELETE' });
      if (!res.ok) {
        const errBody = await res.json();
        setDeleteResult(prettifyJSON(errBody));
        console.log("DELETE response not OK: ", errBody);
      }
      else {
        setDeleteResult(`Status: ${res.status}. Message: ${res.statusText}`);
        console.log("DELETE response OK, no JSON here");
      }
    }
    catch (err) {
      setDeleteResult(String(err));
    }
  }


  return (
    <main className="container">

      <section className="fetch-card" id="get-card">

        <header className="card-header">

          <h3>GET</h3>

          <button

            className="fetch-button btn-get"

            data-method="GET"

            onClick={clickGET}

          >

            Send

          </button>

        </header>

        <label className="input-label">Response JSON</label>

        <div className="result result-get" data-role="result">{getResult}</div>

      </section>


      <section className="fetch-card" id="post-card">

        <header className="card-header">

          <h3>POST</h3>

          <button

            className="fetch-button btn-post"

            data-method="POST"

            onClick={clickPOST}

          >

            Send

          </button>

        </header>

        <label className="input-label">Request JSON</label>

        <textarea

          className="json-input input-post"

          placeholder='{"op":add,"X":"1","Y":"2"}'

          spellCheck="false"

          rows={6}

          value={postInput}

          onChange={(e) => setPostInput(e.target.value)}

        />

        <label className="input-label">Response JSON</label>

        <div className="result result-post" data-role="result">{postResult}</div>

      </section>


      <section className="fetch-card" id="put-card">

        <header className="card-header">

          <h3>PUT</h3>

          <button

            className="fetch-button btn-put"

            data-method="PUT"

            onClick={clickPUT}

          >

            Send

          </button>

        </header>

        <label className="input-label">Request JSON</label>

        <textarea

          className="json-input input-put"

          placeholder='{"op":add,"X":"1","Y":"2"}'

          spellCheck="false"

          rows={6}

          value={putInput}

          onChange={(e) => setPutInput(e.target.value)}

        />

        <label className="input-label">Response JSON</label>

        <div className="result result-put" data-role="result">{putResult}</div>

      </section>


      <section className="fetch-card" id="delete-card">

        <header className="card-header">

          <h3>DELETE</h3>

          <button

            className="fetch-button btn-delete"

            data-method="DELETE"

            onClick={clickDELETE}

          >

            Send

          </button>

        </header>

        <label className="input-label">Response JSON</label>

        <div className="result result-delete" data-role="result">{deleteResult}</div>

      </section>

    </main>
  )
}

export default App
