"""
KeywordMatcher -- O(n) multi-pattern keyword matching using Aho-Corasick automaton.

Uses pyahocorasick for efficient simultaneous matching of thousands of keywords
against input text in a single pass.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional

import ahocorasick


# Level priority mapping: higher number = stricter
_LEVEL_PRIORITY = {
    "pass": 0,
    "mask": 1,
    "review": 2,
}


@dataclass
class MatchResult:
    """Result of keyword matching."""
    has_match: bool = False
    matches: List[Dict] = field(default_factory=list)  # [{word, category, level}]
    strictest_level: str = "pass"  # pass < mask < review


class KeywordMatcher:
    """
    Multi-pattern keyword matcher using Aho-Corasick automaton.

    Keywords are dicts with keys: word, category, level.
    Level can be: 'pass', 'mask', 'review'.
    """

    def __init__(self, keywords: Optional[List[Dict]] = None):
        self._automaton: Optional[ahocorasick.Automaton] = None
        if keywords:
            self.rebuild(keywords)

    def rebuild(self, keywords: List[Dict]) -> None:
        """Rebuild the Aho-Corasick automaton from a list of keyword dicts."""
        automaton = ahocorasick.Automaton()

        for kw in keywords:
            word = kw.get("word", "")
            if not word:
                continue
            # Store the keyword metadata as the value
            automaton.add_word(word, {
                "word": word,
                "category": kw.get("category", ""),
                "level": kw.get("level", "pass"),
            })

        automaton.make_automaton()
        self._automaton = automaton

    def match(self, text: Optional[str]) -> MatchResult:
        """
        Match keywords against the input text.

        Returns MatchResult with deduplicated matches and the strictest level found.
        """
        if not text or self._automaton is None:
            return MatchResult()

        seen_words = set()
        matches: List[Dict] = []
        strictest_priority = 0
        strictest_level = "pass"

        for _, kw_data in self._automaton.iter(text):
            word = kw_data["word"]
            if word in seen_words:
                continue
            seen_words.add(word)
            matches.append(kw_data)

            level = kw_data.get("level", "pass")
            priority = _LEVEL_PRIORITY.get(level, 0)
            if priority > strictest_priority:
                strictest_priority = priority
                strictest_level = level

        return MatchResult(
            has_match=len(matches) > 0,
            matches=matches,
            strictest_level=strictest_level,
        )
