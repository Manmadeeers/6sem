const express = require('express');
const path = require('path');
const fs = require('fs').promises;
const { engine } = require('express-handlebars');
const Handlebars = require('handlebars');

const app = express();
const PORT = 3000;
const DATA_FILE = path.join(__dirname, 'phonebook.json');

async function readData() {
  try {
    const txt = await fs.readFile(DATA_FILE, 'utf8');
    return JSON.parse(txt);
  } catch (e) {
    return { contacts: [] };
  }
}
async function writeData(data) {
  await fs.writeFile(DATA_FILE, JSON.stringify(data, null, 2), 'utf8');
}


app.engine('handlebars', engine({
  defaultLayout: 'main',
  layoutsDir: path.join(__dirname, 'views', 'layouts'),
  partialsDir: path.join(__dirname, 'views', 'partials'),
  helpers: {
    cancelButton: function() {
      return `<a class="cancel-btn" href="/">Отказаться</a>`;
    }
  }
}));
app.set('view engine', 'handlebars');
app.set('views', path.join(__dirname, 'views'));


app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

app.get('/', async (req, res) => {
  const data = await readData();
  res.render('home', { contacts: data.contacts });
});


app.get('/Add', async (req, res) => {
  const data = await readData();
  // blockedRows true -> partial will render disabled row links
  res.render('add', { contacts: data.contacts, blockedRows: true });
});


app.post('/Add', async (req, res) => {
  const { name, phone } = req.body;
  const data = await readData();
  const nextId = (data.contacts.length === 0) ? 1 : Math.max(...data.contacts.map(c => c.id)) + 1;
  data.contacts.push({ id: nextId, name: (name || '').trim(), phone: (phone || '').trim() });
  await writeData(data);
  res.redirect('/');
});


app.get('/Update', async (req, res) => {
  const id = parseInt(req.query.id, 10);
  const data = await readData();
  const contact = data.contacts.find(c => c.id === id);
  if (!contact) {
    return res.redirect('/');
  }
  res.render('update', { contacts: data.contacts, contact, blockedRows: true });
});


app.post('/Update', async (req, res) => {
  const { id, name, phone } = req.body;
  const data = await readData();
  const idx = data.contacts.findIndex(c => c.id === parseInt(id, 10));
  if (idx !== -1) {
    data.contacts[idx].name = (name || '').trim();
    data.contacts[idx].phone = (phone || '').trim();
    await writeData(data);
  }
  res.redirect('/');
});


app.post('/Delete', async (req, res) => {
  const { id } = req.body;
  const data = await readData();
  data.contacts = data.contacts.filter(c => c.id !== parseInt(id, 10));
  await writeData(data);
  res.redirect('/');
});

app.listen(PORT, () => {
  console.log(`20-01 phonebook listening on http://localhost:${PORT}`);
});