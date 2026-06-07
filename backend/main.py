"""FastAPI backend for the Language Learning app.

Combines FSRS spaced repetition with LLM-generated multimodal content.
"""
import os
from datetime import datetime, timezone
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, Depends, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from database import init_db, get_db
from models import (
    Word, Card, GeneratedContent, Review,
    WordCreate, WordOut, CardOut, ReviewSubmit,
    GeneratedContentOut, ReviewSessionOut, StatsOut,
)
from scheduler import FSRSWrapper
from llm_generator import generate_and_save_all, generate_story, save_generated_content

load_dotenv()

app = FastAPI(
    title="LangLearn API",
    description="FSRS-powered Spaced Repetition + LLM Content Generation",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

fsrs = FSRSWrapper(desired_retention=0.9)


# ── Lifecycle ───────────────────────────────────────────────

@app.on_event("startup")
def on_startup():
    init_db()


# ── Word Endpoints ──────────────────────────────────────────

@app.post("/api/words", response_model=WordOut)
def add_word(data: WordCreate, db: Session = Depends(get_db)):
    """Add a new word, create its FSRS card, and trigger LLM generation."""
    existing = db.query(Word).filter(Word.word == data.word).first()
    if existing:
        raise HTTPException(status_code=409, detail=f"Word '{data.word}' already exists")

    word = Word(
        word=data.word,
        translation=data.translation,
        language=data.language or "",
        notes=data.notes,
    )
    db.add(word)
    db.commit()
    db.refresh(word)

    # Create FSRS card
    fsrs.create_card(word.id, db)

    # Trigger LLM content generation (in background in production)
    try:
        generate_and_save_all(word.id, word.word, word.translation, db)
    except Exception as e:
        # Don't fail the request — content can be regenerated later
        pass

    return word


@app.get("/api/words", response_model=list[WordOut])
def list_words(
    language: Optional[str] = Query(None),
    limit: int = Query(100, le=500),
    db: Session = Depends(get_db),
):
    """List all words, optionally filtered by language."""
    query = db.query(Word)
    if language:
        query = query.filter(Word.language == language)
    return query.order_by(Word.created_at.desc()).limit(limit).all()


@app.get("/api/words/{word_id}", response_model=WordOut)
def get_word(word_id: int, db: Session = Depends(get_db)):
    word = db.query(Word).filter(Word.id == word_id).first()
    if not word:
        raise HTTPException(status_code=404, detail="Word not found")
    return word


@app.delete("/api/words/{word_id}")
def delete_word(word_id: int, db: Session = Depends(get_db)):
    """Delete a word and its associated card/content."""
    word = db.query(Word).filter(Word.id == word_id).first()
    if not word:
        raise HTTPException(status_code=404, detail="Word not found")
    db.delete(word)  # cascade handles card, content, reviews
    db.commit()
    return {"status": "deleted", "id": word_id}


# ── Review Endpoints ────────────────────────────────────────

@app.get("/api/review/due", response_model=list[ReviewSessionOut])
def get_due_reviews(limit: int = Query(10, le=50), db: Session = Depends(get_db)):
    """Get cards due for review, with their generated content."""
    due_cards = fsrs.get_due_cards(db, limit=limit)
    result = []
    for card, retrievability in due_cards:
        word = card.word
        content = (
            db.query(GeneratedContent)
            .filter(
                GeneratedContent.word_id == word.id,
                GeneratedContent.is_active == 1,
            )
            .order_by(GeneratedContent.created_at.desc())
            .all()
        )
        result.append({
            "card_id": card.id,
            "word_id": word.id,
            "word": word.word,
            "translation": word.translation,
            "content": [GeneratedContentOut.model_validate(c) for c in content],
            "stats": {
                "stability": round(card.stability, 2),
                "difficulty": round(card.difficulty, 2),
                "retrievability": round(retrievability, 3),
                "reps": card.reps,
                "state": card.state,
            },
        })
    return result


@app.post("/api/review/submit")
def submit_review(data: ReviewSubmit, db: Session = Depends(get_db)):
    """Submit a review grade and update the FSRS schedule."""
    card = db.query(Card).filter(Card.id == data.card_id).first()
    if not card:
        raise HTTPException(status_code=404, detail="Card not found")

    if data.grade < 1 or data.grade > 4:
        raise HTTPException(status_code=400, detail="Grade must be 1-4 (Again/Hard/Good/Easy)")

    updated_card, review_log = fsrs.review_card(
        card, data.grade, db, duration_ms=data.duration_ms
    )

    return {
        "card_id": updated_card.id,
        "word_id": updated_card.word_id,
        "next_due": updated_card.due.isoformat(),
        "state": updated_card.state,
        "stability": round(updated_card.stability, 2),
        "difficulty": round(updated_card.difficulty, 2),
        "grade": data.grade,
    }


@app.get("/api/stats", response_model=StatsOut)
def get_stats(db: Session = Depends(get_db)):
    """Get learning statistics."""
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    total_words = db.query(Word).count()
    words_learned = db.query(Card).filter(Card.state == "Review").count()
    words_learning = db.query(Card).filter(Card.state.in_(["Learning", "Relearning"])).count()
    words_new = db.query(Card).filter(Card.state == "New").count()
    due_today = db.query(Card).filter(Card.due <= now).count()
    reviews_today = db.query(Review).filter(Review.reviewed_at >= today_start).count()
    avg_stability = db.query(Card.stability).filter(Card.stability > 0).all()
    avg_s = sum(s[0] for s in avg_stability) / len(avg_stability) if avg_stability else 0.0

    return StatsOut(
        total_words=total_words,
        words_learned=words_learned,
        words_learning=words_learning,
        words_new=words_new,
        due_today=due_today,
        reviews_today=reviews_today,
        average_stability=round(avg_s, 2),
    )


# ── Content Generation Endpoints ────────────────────────────

@app.post("/api/generate/{word_id}")
def regenerate_content(word_id: int, db: Session = Depends(get_db)):
    """Regenerate LLM content for a word."""
    word = db.query(Word).filter(Word.id == word_id).first()
    if not word:
        raise HTTPException(status_code=404, detail="Word not found")

    # Mark existing content as inactive
    db.query(GeneratedContent).filter(
        GeneratedContent.word_id == word_id,
        GeneratedContent.is_active == 1,
    ).update({"is_active": 0})
    db.commit()

    # Generate fresh content
    try:
        contents = generate_and_save_all(word.id, word.word, word.translation, db)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Generation failed: {str(e)}")

    return {
        "word": word.word,
        "generated": len(contents),
        "content": [GeneratedContentOut.model_validate(c) for c in contents],
    }


@app.post("/api/generate/story")
def generate_story_endpoint(
    word_ids: list[int] = Query(..., description="List of word IDs to include in the story"),
    level: str = Query("beginner"),
    db: Session = Depends(get_db),
):
    """Generate a story using multiple target words."""
    words = db.query(Word).filter(Word.id.in_(word_ids)).all()
    if len(words) < 2:
        raise HTTPException(status_code=400, detail="Need at least 2 words for a story")

    word_pairs = [(w.word, w.translation) for w in words]
    story = generate_story(word_pairs, level=level)
    if not story:
        raise HTTPException(status_code=500, detail="Story generation failed")

    # Save story for each word
    for w in words:
        save_generated_content(w.id, "story", story, db)

    return {"story": story, "words": [w.word for w in words]}
