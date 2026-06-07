# LangLearn — FSRS + LLM Language Learning Prototype

A full-stack prototype combining **FSRS spaced repetition** with **LLM-generated multimodal content** for accelerated vocabulary acquisition.

## Architecture

```
flutter_app/  →  HTTP/REST  →  FastAPI Backend  →  SQLite
    │                           │
    │                     ┌─────┴─────┐
    │                     │  FSRS     │
    │                     │  Scheduler│
    │                     └───────────┘
    │                     ┌───────────┐
    │                     │  LLM Gen  │
    │                     │  (text,   │
    │                     │   audio,  │
    │                     │   images) │
    │                     └───────────┘
```

## Backend (FastAPI + FSRS)

### Setup
```bash
cd backend
pip install -r requirements.txt
cp .env.example .env
# Edit .env — set LLM_API_KEY for AI content generation
uvicorn main:app --reload --port 8000
```

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/words` | Add a word + FSRS card + LLM content |
| GET | `/api/words` | List all words |
| GET | `/api/words/{id}` | Get word details |
| DELETE | `/api/words/{id}` | Delete word and all progress |
| GET | `/api/review/due` | Get due cards with generated content |
| POST | `/api/review/submit` | Submit review grade → FSRS update |
| GET | `/api/stats` | Learning statistics |
| POST | `/api/generate/{id}` | Regenerate LLM content |
| POST | `/api/generate/story` | Generate story from multiple words |

### FSRS Integration
- Uses `py-fsrs` (v6.3) — the official Python FSRS implementation
- Default desired retention: 90%
- States: New → Learning → Review → Relearning
- Grades: 1=Again, 2=Hard, 3=Good, 4=Easy

### LLM Content Generation
- Auto-triggered when a word is added (if `LLM_API_KEY` is set)
- Without an API key, falls back to basic template content
- Generates: example sentences (3 levels), cloze tests, definitions, mnemonics, quizzes
- Batch generation supported for cost efficiency

## Flutter App

### Setup
```bash
cd flutter_app
flutter pub get
flutter run
```

### Screens
- **Home Dashboard** — due count, stats, quick actions
- **Word List** — browse, delete words
- **Add Word** — new vocabulary entry
- **Review Session** — FSRS-based review with LLM content
- **Statistics** — learning progress, stability metrics

### Key Features
- FSRS-scheduled card reviews with 4-level grading
- LLM-generated example sentences, cloze tests, mnemonics
- Retrievability indicator per card
- Progress tracking with visual stats

## Cost Estimate (per active user/day)
- LLM text (Claude Haiku / GPT-4o-mini): ~$0.001 / 10-word batch
- TTS audio (Edge TTS = free): ~$0.00
- Image gen (Stable Diffusion self-host): ~$0.00
- **Total: ~$0.001/day per user** for text-only

## Implementation Order
1. ✅ FSRS scheduler + core review loop
2. ✅ LLM text generation (sentences, cloze, mnemonics)
3. ✅ Active recall quiz engine
4. 🔲 TTS audio playback
5. 🔲 Image generation (concrete words)
6. 🔲 Free-write + LLM error correction
7. 🔲 User authentication / multi-user
