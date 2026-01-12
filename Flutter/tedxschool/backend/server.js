const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const axios = require('axios');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// 🔌 Connessione MongoDB
mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log('MongoDB connesso'))
  .catch(err => console.error('Errore MongoDB:', err));

// Schema Classroom
const classroomSchema = new mongoose.Schema({
  name: String,
  assigned_talks: [String], // array di talk_id
  created_at: { type: Date, default: Date.now }
});

const Classroom = mongoose.model('classrooms', classroomSchema);

// Schema Ratings
const ratingSchema = new mongoose.Schema({
  talk_id: String,
  student_id: String,
  rating: Number,
  timestamp: { type: Date, default: Date.now }
});

const Rating = mongoose.model('ratings', ratingSchema);

app.get('/api/talks/classroom/:classId', async (req, res) => {
  try {
    const classroom = await Classroom.findById(req.params.classId);
    if (!classroom) return res.status(404).json({ error: 'Classe non trovata' });
    
    const talks = classroom.assignments 
      ? classroom.assignments.map(a => a.video_id).filter(id => id) 
      : [];
    
    res.json({
      classroom_id: classroom._id,
      classroom_name: classroom.name,
      talks: talks
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/ratings/:talkId', async (req, res) => {
  try {
    const ratings = await Rating.find({ talk_id: req.params.talkId });
    const avg = ratings.length > 0 
      ? (ratings.reduce((sum, r) => sum + r.rating, 0) / ratings.length).toFixed(1)
      : 0;
    
    res.json({
      talk_id: req.params.talkId,
      avg_rating: parseFloat(avg),
      total_votes: ratings.length
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/ratings', async (req, res) => {
  try {
    const { talk_id, student_id, rating } = req.body;
    
    if (rating < 1 || rating > 10) {
      return res.status(400).json({ error: 'Rating deve essere 1-10' });
    }

    const newRating = new Rating({ talk_id, student_id, rating });
    await newRating.save();

    const allRatings = await Rating.find({ talk_id });
    const avg = (allRatings.reduce((sum, r) => sum + r.rating, 0) / allRatings.length).toFixed(1);

    res.json({
      message: 'Voto registrato con successo',
      avg_rating: parseFloat(avg),
      total_votes: allRatings.length
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/talks/search/:talkId', async (req, res) => {
  try {
    const talkId = req.params.talkId;
    
    const response = await axios.get(
      `${process.env.AWS_API_BASE}/watchnext?id=${talkId}`
    );
    
    res.json(response.data);
  } catch (err) {
    res.status(500).json({ error: 'Talk non trovato' });
  }
});

app.post('/api/classroom/:classId/assign', async (req, res) => {
  try {
    const { talk_id } = req.body;
    
    const classroom = await Classroom.findById(req.params.classId);
    if (!classroom) return res.status(404).json({ error: 'Classe non trovata' });

    if (!classroom.assigned_talks.includes(talk_id)) {
      classroom.assigned_talks.push(talk_id);
      await classroom.save();
    }

    res.json({
      message: 'Talk assegnato con successo',
      classroom: classroom
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/classroom/:classId/talks', async (req, res) => {
  try {
    const classroom = await Classroom.findById(req.params.classId);
    if (!classroom) return res.status(404).json({ error: 'Classe non trovata' });
    
    res.json({
      assigned_talks: classroom.assigned_talks
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/health', (req, res) => {
  res.json({ status: 'Backend online ✅' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});