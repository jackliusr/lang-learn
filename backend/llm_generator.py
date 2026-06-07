"""LLM content generator for language learning cards.

Generates example sentences, cloze tests, definitions, and mnemonics
using an OpenAI-compatible API.
"""
import json
import os
from typing import Optional
from datetime import datetime, timezone

import httpx

from models import GeneratedContent
from database import SessionLocal


# ── Configuration ───────────────────────────────────────────

LLM_API_KEY = os.getenv("LLM_API_KEY", "")
LLM_BASE_URL = os.getenv("LLM_BASE_URL", "https://api.openai.com/v1")
LLM_MODEL = os.getenv("LLM_MODEL", "gpt-4o-mini")
L1_LANG = os.getenv("L1_LANG", "Chinese")
L2_LANG = os.getenv("L2_LANG", "English")


def _call_llm(system_prompt: str, user_prompt: str, temperature: float = 0.7) -> str:
    """Make a chat completion call to an OpenAI-compatible API."""
    headers = {
        "Authorization": f"Bearer {LLM_API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": LLM_MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": temperature,
        "response_format": {"type": "json_object"},
    }

    with httpx.Client(timeout=30.0) as client:
        response = client.post(
            f"{LLM_BASE_URL}/chat/completions",
            headers=headers,
            json=payload,
        )
        response.raise_for_status()
        data = response.json()
        return data["choices"][0]["message"]["content"]


# ── Prompt Templates ────────────────────────────────────────

SYSTEM_PROMPT_SENTENCES = f"""You are a language tutor helping a {L1_LANG} speaker learn {L2_LANG}.
Generate natural, level-appropriate content. Return ONLY valid JSON."""

USER_PROMPT_SENTENCES = """For the {L2_LANG} word "{word}" (meaning: {translation} in {L1_LANG}),
generate the following as a JSON object with these keys:

1. "sentences": an array of 3 example sentences using the word naturally.
   Vary the grammatical structure (different tenses, forms). Each should include:
   - "sentence": the {L2_LANG} sentence
   - "translation": the {L1_LANG} translation
   - "difficulty": one of "beginner", "intermediate", "advanced"

2. "definition": a clear {L2_LANG} definition appropriate for a learner

3. "cloze": a fill-in-the-blank version of the first sentence (word blanked out)

4. "mnemonic": a short memory aid connecting the word to {L1_LANG}

Example output format:
{{
  "sentences": [
    {{"sentence": "...", "translation": "...", "difficulty": "beginner"}},
    ...
  ],
  "definition": "...",
  "cloze": "...",
  "mnemonic": "..."
}}"""

USER_PROMPT_STORY = """Write a very short story (3-4 sentences) in {L2_LANG} that naturally uses ALL of these words: {words}.
The story should be at a {level} level.
Then provide a {L1_LANG} translation.

Return JSON: {{"story": "...", "translation": "...", "target_words": ["..."]}}"""

USER_PROMPT_QUIZ = """For the {L2_LANG} word "{word}" (meaning: {translation}),
generate a multiple-choice quiz question where the answer is this word.

Return JSON: {{
  "question": "... (a sentence with a blank where the word should go)",
  "options": ["correct_answer", "distractor1", "distractor2", "distractor3"],
  "correct": "correct_answer",
  "hint": "... (clue in {L1_LANG})"
}}

Make distractors plausible — similar in meaning or form."""


# ── Content Generation ──────────────────────────────────────

def generate_all_content(word_text: str, translation: str) -> dict:
    """Generate all content types for a word in a single LLM call."""
    prompt = USER_PROMPT_SENTENCES.format(
        word=word_text,
        translation=translation,
        L1_LANG=L1_LANG,
        L2_LANG=L2_LANG,
    )
    try:
        result = _call_llm(SYSTEM_PROMPT_SENTENCES, prompt)
        return json.loads(result)
    except Exception as e:
        return {
            "sentences": [{"sentence": f"Example sentence for {word_text}.",
                           "translation": translation,
                           "difficulty": "beginner"}],
            "definition": f"A {L2_LANG} word meaning {translation}.",
            "cloze": f"Example ___ for {word_text}.",
            "mnemonic": f"Associate '{word_text}' with '{translation}'.",
        }


def generate_story(words_with_translations: list[tuple[str, str]],
                   level: str = "beginner") -> Optional[dict]:
    """Generate a story using multiple target words."""
    word_list = [w for w, _ in words_with_translations]
    if len(word_list) < 2:
        return None
    prompt = USER_PROMPT_STORY.format(
        words=", ".join(word_list),
        level=level,
        L1_LANG=L1_LANG,
        L2_LANG=L2_LANG,
    )
    try:
        result = _call_llm(SYSTEM_PROMPT_SENTENCES, prompt)
        return json.loads(result)
    except Exception:
        return None


def generate_quiz(word_text: str, translation: str) -> Optional[dict]:
    """Generate a multiple-choice quiz for a word."""
    prompt = USER_PROMPT_QUIZ.format(
        word=word_text,
        translation=translation,
        L1_LANG=L1_LANG,
        L2_LANG=L2_LANG,
    )
    try:
        result = _call_llm(SYSTEM_PROMPT_SENTENCES, prompt)
        return json.loads(result)
    except Exception:
        return None


def save_generated_content(word_id: int, content_type: str,
                            content_data: dict, db) -> GeneratedContent:
    """Save generated content to the database."""
    gc = GeneratedContent(
        word_id=word_id,
        content_type=content_type,
        content=content_data,
        created_at=datetime.now(timezone.utc),
    )
    db.add(gc)
    db.commit()
    db.refresh(gc)
    return gc


def generate_and_save_all(word_id: int, word_text: str, translation: str, db) -> list[GeneratedContent]:
    """Generate all content for a word and save to DB."""
    results = []

    # Generate sentences + cloze + definition + mnemonic
    content = generate_all_content(word_text, translation)
    gc = save_generated_content(word_id, "full_content", content, db)
    results.append(gc)

    # Generate quiz
    quiz = generate_quiz(word_text, translation)
    if quiz:
        gc = save_generated_content(word_id, "quiz", quiz, db)
        results.append(gc)

    return results
