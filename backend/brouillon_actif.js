// backend/index.js
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// Route health
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString()
  });
});

// Exemple d'autre route
app.get('/', (req, res) => {
  res.send('Backend actif 🚀');
});

app.listen(PORT, () => {
  console.log(`Serveur démarré sur http://localhost:${PORT}`);
});