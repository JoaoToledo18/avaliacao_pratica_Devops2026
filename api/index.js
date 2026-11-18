const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');

const app = express();
app.use(express.json());
app.use(cors({
  origin: process.env.WEB_ORIGIN || '*',
  methods: ['GET', 'POST', 'OPTIONS']
}));

const db = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME
});

app.post('/curso', async (req, res, next) => {
  try {
    const { nome, instrutor, preco, vagas } = req.body;
    if (!nome || !instrutor || preco === undefined || vagas === undefined) {
      return res.status(400).json({ erro: 'Campos obrigatorios: nome, instrutor, preco, vagas' });
    }
    const [r] = await db.query(
      'INSERT INTO cursos (nome, instrutor, preco, vagas) VALUES (?, ?, ?, ?)',
      [nome, instrutor, preco, vagas]
    );
    res.status(201).json({ id: r.insertId, nome, instrutor, preco, vagas });
  } catch (e) { next(e); }
});

app.get('/cursos', async (req, res, next) => {
  try {
    const [rows] = await db.query('SELECT * FROM cursos');
    res.json(rows);
  } catch (e) { next(e); }
});

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ erro: 'Erro no servidor' });
});

app.listen(3000, () => console.log('API rodando na porta 3000'));
