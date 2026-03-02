const express = require('express');
const PORT = 3000;
const studentsRouter = require('./router/studentsRoutes');
const methodOverride = require('method-override');
const path = require('path');
const app = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(methodOverride('_method'));

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.use(express.static(path.join(__dirname, 'public')));


app.use('/students', studentsRouter);

app.get('/', (req, res) => res.redirect('/students'));

app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
});