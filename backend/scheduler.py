"""FSRS scheduler wrapper for language learning cards."""
from datetime import datetime, timezone
from typing import Optional

from fsrs import Scheduler as FSRSScheduler, Card as FSRSCard, Rating, ReviewLog
from sqlalchemy.orm import Session

from models import Card, Review


class FSRSWrapper:
    """Wraps the py-fsrs Scheduler for our Card model."""

    def __init__(self, desired_retention: float = 0.9):
        self.scheduler = FSRSScheduler(
            desired_retention=desired_retention,
            enable_fuzzing=True,
        )

    def create_card(self, word_id: int, db: Session) -> Card:
        """Create a new Card record for a word, initialized with FSRS defaults."""
        now = datetime.now(timezone.utc)
        fsrs_card = FSRSCard()

        db_card = Card(
            word_id=word_id,
            due=fsrs_card.due,
            stability=fsrs_card.stability or 0.0,
            difficulty=fsrs_card.difficulty or 0.0,
            elapsed_days=0,
            scheduled_days=0,
            reps=0,
            lapses=0,
            state=fsrs_card.state.name,
            fsrs_state=self._card_to_dict(fsrs_card),
        )
        db.add(db_card)
        db.commit()
        db.refresh(db_card)
        return db_card

    def review_card(self, db_card: Card, grade: int, db: Session,
                    review_datetime: Optional[datetime] = None,
                    duration_ms: Optional[int] = None) -> tuple[Card, Review]:
        """Process a review: update FSRS state and log the review."""
        if review_datetime is None:
            review_datetime = datetime.now(timezone.utc)

        fsrs_card = self._dict_to_card(db_card.fsrs_state)
        rating = Rating(grade)  # 1=Again, 2=Hard, 3=Good, 4=Easy

        new_fsrs_card, review_log = self.scheduler.review_card(
            fsrs_card, rating, review_datetime, duration_ms
        )

        # Update the db card
        db_card.fsrs_state = self._card_to_dict(new_fsrs_card)
        db_card.due = new_fsrs_card.due
        db_card.stability = new_fsrs_card.stability or 0.0
        db_card.difficulty = new_fsrs_card.difficulty or 0.0

        # Track interval info
        if db_card.last_reviewed:
            days = (review_datetime - db_card.last_reviewed).days
            db_card.elapsed_days = max(0, days)
        if new_fsrs_card.due:
            days = (new_fsrs_card.due - review_datetime).days
            db_card.scheduled_days = max(0, days)

        db_card.reps = (db_card.reps or 0) + 1
        if grade == 1:  # Again = failed
            db_card.lapses = (db_card.lapses or 0) + 1
        db_card.state = new_fsrs_card.state.name
        db_card.last_reviewed = review_datetime

        # Log the review
        db_review = Review(
            card_id=db_card.id,
            grade=grade,
            reviewed_at=review_datetime,
            duration_ms=duration_ms,
        )
        db.add(db_review)
        db.commit()
        db.refresh(db_card)
        db.refresh(db_review)

        return db_card, db_review

    def get_due_cards(self, db: Session, limit: int = 20) -> list[tuple[Card, float]]:
        """Get cards due for review, ordered by due date.
        Returns (Card, retrievability) pairs."""
        now = datetime.now(timezone.utc)
        cards = (
            db.query(Card)
            .filter(Card.due <= now)
            .order_by(Card.due.asc())
            .limit(limit)
            .all()
        )
        result = []
        for card in cards:
            fsrs_card = self._dict_to_card(card.fsrs_state)
            retrievability = self.scheduler.get_card_retrievability(fsrs_card, now)
            result.append((card, retrievability))
        return result

    def _card_to_dict(self, card: FSRSCard) -> dict:
        return {
            "card_id": card.card_id,
            "due": card.due.isoformat() if card.due else None,
            "stability": card.stability,
            "difficulty": card.difficulty,
            "state": card.state.name if card.state else "New",
            "last_review": card.last_review.isoformat() if card.last_review else None,
            "step": card.step,
        }

    def _dict_to_card(self, data: dict) -> FSRSCard:
        card = FSRSCard()
        if data.get("card_id"):
            card.card_id = data["card_id"]
        if data.get("due"):
            card.due = datetime.fromisoformat(data["due"])
        if data.get("stability") is not None:
            card.stability = data["stability"]
        if data.get("difficulty") is not None:
            card.difficulty = data["difficulty"]
        if data.get("step") is not None:
            card.step = data["step"]
        if data.get("last_review"):
            card.last_review = datetime.fromisoformat(data["last_review"])
        if data.get("state"):
            from fsrs.state import State
            card.state = State[data["state"]]
        return card
