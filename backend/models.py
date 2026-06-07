"""SQLAlchemy ORM models and Pydantic schemas."""
import json
from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Float, DateTime, Text, ForeignKey, JSON
from sqlalchemy.orm import relationship
from pydantic import BaseModel
from typing import Optional, Any

from database import Base


# ── ORM Models ──────────────────────────────────────────────

class Word(Base):
    """A vocabulary word the user is learning."""
    __tablename__ = "words"

    id = Column(Integer, primary_key=True, index=True)
    word = Column(String(255), nullable=False, index=True)
    translation = Column(String(255), nullable=False)
    language = Column(String(50), nullable=False, default="")
    notes = Column(Text, default="")
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    card = relationship("Card", back_populates="word", uselist=False, cascade="all, delete-orphan")
    generated_content = relationship("GeneratedContent", back_populates="word", cascade="all, delete-orphan")


class Card(Base):
    """An FSRS-managed flashcard for a word."""
    __tablename__ = "cards"

    id = Column(Integer, primary_key=True, index=True)
    word_id = Column(Integer, ForeignKey("words.id", ondelete="CASCADE"), nullable=False, unique=True)
    # FSRS state — serialized as JSON for simplicity
    fsrs_state = Column(JSON, nullable=False, default=dict)
    # Denormalized fields for fast queries
    due = Column(DateTime(timezone=True), nullable=False)
    stability = Column(Float, default=0.0)
    difficulty = Column(Float, default=0.0)
    elapsed_days = Column(Integer, default=0)
    scheduled_days = Column(Integer, default=0)
    reps = Column(Integer, default=0)
    lapses = Column(Integer, default=0)
    state = Column(String(20), default="New")  # New, Learning, Review, Relearning
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    last_reviewed = Column(DateTime(timezone=True), nullable=True)

    word = relationship("Word", back_populates="card")
    reviews = relationship("Review", back_populates="card", cascade="all, delete-orphan")


class Review(Base):
    """Individual review log entry."""
    __tablename__ = "reviews"

    id = Column(Integer, primary_key=True, index=True)
    card_id = Column(Integer, ForeignKey("cards.id", ondelete="CASCADE"), nullable=False)
    grade = Column(Integer, nullable=False)  # 1=Again, 2=Hard, 3=Good, 4=Easy
    reviewed_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    duration_ms = Column(Integer, nullable=True)

    card = relationship("Card", back_populates="reviews")


class GeneratedContent(Base):
    """LLM-generated content for a word (sentences, cloze, stories, etc.)."""
    __tablename__ = "generated_content"

    id = Column(Integer, primary_key=True, index=True)
    word_id = Column(Integer, ForeignKey("words.id", ondelete="CASCADE"), nullable=False)
    content_type = Column(String(50), nullable=False)  # sentence, cloze, story, definition, mnemonic
    content = Column(JSON, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    is_active = Column(Integer, default=1)  # soft-flag for regeneration

    word = relationship("Word", back_populates="generated_content")


# ── Pydantic Schemas ────────────────────────────────────────

class WordCreate(BaseModel):
    word: str
    translation: str
    language: str = ""
    notes: str = ""

class WordOut(BaseModel):
    id: int
    word: str
    translation: str
    language: str
    notes: str
    created_at: datetime

    model_config = {"from_attributes": True}

class CardOut(BaseModel):
    id: int
    word_id: int
    word: str
    translation: str
    due: datetime
    stability: float
    difficulty: float
    reps: int
    lapses: int
    state: str

    model_config = {"from_attributes": True}

class ReviewSubmit(BaseModel):
    card_id: int
    grade: int  # 1=Again, 2=Hard, 3=Good, 4=Easy
    duration_ms: Optional[int] = None

class GeneratedContentOut(BaseModel):
    id: int
    content_type: str
    content: dict
    created_at: datetime

    model_config = {"from_attributes": True}

class ReviewSessionOut(BaseModel):
    """What the Flutter app needs to render a review card."""
    card_id: int
    word_id: int
    word: str
    translation: str
    content: list[GeneratedContentOut]
    stats: dict

    model_config = {"from_attributes": True}

class StatsOut(BaseModel):
    total_words: int
    words_learned: int  # cards in Review state
    words_learning: int  # cards in Learning state
    words_new: int  # cards in New state
    due_today: int
    reviews_today: int
    average_stability: float

    model_config = {"from_attributes": True}
