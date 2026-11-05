#!/usr/bin/env python3
"""Trains the on-device synergy data from the bundled perk and add-on descriptions.

Pure standard library. Run from the repo root:  python3 tools/synergy/build_synergy.py

Per item it extracts mechanic tags (what it produces, what it consumes, shared themes) and learns a small
TF-IDF + truncated-SVD embedding. The app scores complementarity (producer -> consumer), not text similarity.
"""
import json
import math
import random
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RESOURCES = ROOT / "DBD Perks" / "Resources"
OUTPUT = RESOURCES / "synergy.json"
SCHEMA_VERSION = 1
EMBEDDING_DIMENSIONS = 16
ITERATIONS = 25
MIN_DOCUMENT_FREQUENCY = 2
SEED = 7

# Status effects: a tag in a condition clause is consumed, in an effect clause (or with a giving verb) produced.
STATUS_TAGS = {
    "Exposed": r"\bexposed\b",
    "Hindered": r"\bhindered\b",
    "Haste": r"\bhaste\b",
    "Endurance": r"\bendurance\b",
    "Deep Wound": r"\bdeep wound\b",
    "Mangled": r"\bmangled\b",
    "Hemorrhage": r"\bhemorrhage\b",
    "Blindness": r"\bblind(?:ness|ed)?\b",
    "Broken": r"\bbroken\b",
    "Oblivious": r"\boblivious\b",
    "Exhausted": r"\bexhausted\b",
    "Undetectable": r"\bundetectable\b",
    "Incapacitated": r"\bincapacitated\b",
    "Haunted": r"\bhaunted\b",
    "Madness": r"\bmadness\b",
    "Cursed": r"\bcursed?\b",
    "Slowed": r"\bslowed|\bslowdown\b",
    "Sloppy": r"\bsloppy\b",
    "Poisoned": r"\bpoison",
    "Elusive": r"\belusive\b",
    "Obsession": r"\bobsession\b",
    "Hex": r"\bhex\b",
    "Scourge Hook": r"\bscourge hook",
    "Dying": r"\bdying state\b|\bdeep wound\b",
    "Injured": r"\binjured\b",
    "Downed": r"\bdowned\b|\bdowns?\b",
    "Hooked": r"\bhooked\b|\bhook(?:s|ed)?\b",
    "Healing": r"\bheal(?:ing|ed|s)?\b",
    "Totem": r"\btotems?\b",
    "Aura": r"\bauras?\b",
    "Terror Radius": r"\bterror radius\b",
    "Generator": r"\bgenerators?\b",
    "Pallet": r"\bpallets?\b",
    "Chase": r"\bchase\b",
    "Sprint Burst": r"\bsprint burst\b",
}

# Statuses that are mere game objects: shared context rather than something one item "gives" another.
CONTEXT_TAGS = {"Injured", "Downed", "Hooked", "Healing", "Totem", "Aura", "Terror Radius", "Generator",
                "Pallet", "Chase", "Obsession", "Elusive"}

# Themes: strategies two items both lean on (they stack).
THEMES = {
    "Generator pressure": r"generator.*(?:regress|block|slow|kick|damage|speed)|(?:regress|block|slow|kick|damage).*generator",
    "Aura reading": r"\b(?:see|reveal|view)\w*\b.*\bauras?\b|\bauras?\b.*\b(?:revealed|visible)",
    "Chase": r"\bchase\b",
    "Stealth": r"\bundetectable\b|\bterror radius\b.*\b(?:smaller|reduced|no longer)\b|\bstealth\b",
    "Tracking": r"\bscratch marks\b|\bkiller instinct\b|\bnotification",
    "Healing": r"\bheal",
    "Hooks": r"\bhook",
    "Speed": r"\bhaste\b|\bmovement speed\b|\bsprint burst\b",
    "Exhaustion": r"\bexhaust",
    "Totems": r"\btotem",
    "Sabotage": r"\bsabotage|\btoolbox|\bbeartrap",
    "Vaulting": r"\bvault|\bpallet|\bwindow",
    "Items": r"\bitem\b|\bflashlight|\bmed-?kit|\bkey\b|\bmap\b",
    "Information": r"\bnotif|\bsee the\b|\bauras?\b",
    "Slowdown": r"\bhindered\b|\bslow|\bregress",
    "Endurance": r"\bendurance\b|\bprotection hit",
}

# Add-ons tune one power, so what they share is the stat they push rather than a status effect.
ADDON_THEMES = {
    "Cooldown": r"\bcooldown|\brecovery|\bdelay|\bcooldowns?\b",
    "Duration": r"\bduration|\blasts?\b|\bseconds longer",
    "Range": r"\brange|\bradius|\bdistance|\bwider|\blarger",
    "Charges": r"\bcharge|\btokens?\b|\bstacks?\b",
    "Movement speed": r"\bmovement speed|\bspeed\b|\bfaster",
    "Damage": r"\bdamage|\bhit|\battack",
    "Detection": r"\bsee\b|\bnotif|\bdetect|\breveal|\bauras?\b",
}

GIVING_VERB = re.compile(r"\b(?:inflicts?|applies|apply|gains?|grants?|causes?|suffers?|afflicts?|receives?|becomes?|"
                         r"will be|are|is|get|gets|refresh(?:es)?|trigger(?:s)?)\b", re.I)
TRIGGER = re.compile(r"\b(?:while|when|whenever|if|after|once|as long as|each time|for each|unless)\b", re.I)
STOP_WORDS = set("""the and for you your are that this with from his her they them their will can have has had not but any
all one two per its also then than when while whenever each into out off who what which only more most other such
survivor survivors killer killers seconds second meters metres within""".split())


def body_of(description):
    """Add-on text opens with a lore line; the mechanics follow the first blank line."""
    parts = [part.strip() for part in re.split(r"\n\s*\n", description) if part.strip()]
    return " \n".join(parts[1:]) if len(parts) > 1 else (parts[0] if parts else "")


def split_clauses(text):
    """Yields (condition, effect) pairs. A bullet inherits the header line that ends with ':'."""
    header = ""
    for raw in text.splitlines():
        line = raw.strip().lstrip("•-* ").strip()
        if not line:
            header = ""
            continue
        if raw.strip().startswith(("•", "-", "*")) and header:
            yield header, line
            continue
        header = line.rstrip(":") if line.endswith(":") else ""
        if line.endswith(":"):
            continue
        for sentence in re.split(r"(?<=[.!?])\s+", line):
            yield from split_sentence(sentence)


def split_sentence(sentence):
    match = TRIGGER.search(sentence)
    if not match:
        yield "", sentence
        return
    rest = sentence[match.start():]
    comma = rest.find(",")
    if comma == -1:
        yield "", sentence
    else:
        yield rest[:comma], sentence[:match.start()] + rest[comma + 1:]


def mentioned(pattern_map, text):
    return {tag for tag, pattern in pattern_map.items() if re.search(pattern, text, re.I)}


def extract_tags(name, description, is_addon=False):
    """Returns (produces, consumes, themes) as sorted tag lists."""
    produces, consumes, themes = set(), set(), set()
    text = body_of(description)
    for condition, effect in split_clauses(text):
        consumes |= mentioned(STATUS_TAGS, condition)
        for tag in mentioned(STATUS_TAGS, effect):
            if tag in CONTEXT_TAGS:
                continue
            if GIVING_VERB.search(effect):
                produces.add(tag)
            else:
                consumes.add(tag)
    if re.match(r"hex\b", name, re.I):
        produces.add("Hex")
    for tag in mentioned(THEMES, text):
        themes.add(tag)
    if is_addon:
        themes |= mentioned(ADDON_THEMES, text)
    consumes -= {tag for tag in consumes if tag in produces and not re.search(
        r"\b(?:while|when|whenever|if)\b[^.]*" + STATUS_TAGS[tag], text, re.I)}
    return sorted(produces), sorted(consumes - {"Hex"} if "Hex" in produces else consumes), sorted(themes)


def tokenize(text):
    words = re.findall(r"[a-z']+", text.lower())
    return [word for word in words if len(word) > 2 and word not in STOP_WORDS]


def tf_idf(documents):
    counts = [{} for _ in documents]
    frequency = {}
    for index, tokens in enumerate(documents):
        for token in tokens:
            counts[index][token] = counts[index].get(token, 0) + 1
        for token in counts[index]:
            frequency[token] = frequency.get(token, 0) + 1
    vocabulary = {token: i for i, token in enumerate(sorted(t for t, f in frequency.items() if f >= MIN_DOCUMENT_FREQUENCY))}
    total = len(documents)
    rows = []
    for count in counts:
        row = {vocabulary[t]: (1 + math.log(c)) * math.log((1 + total) / (1 + frequency[t])) for t, c in count.items() if t in vocabulary}
        norm = math.sqrt(sum(v * v for v in row.values())) or 1.0
        rows.append({k: v / norm for k, v in row.items()})
    return rows, len(vocabulary)


def orthonormalize(columns):
    for index, column in enumerate(columns):
        for previous in columns[:index]:
            dot = sum(a * b for a, b in zip(column, previous))
            column[:] = [a - dot * b for a, b in zip(column, previous)]
        norm = math.sqrt(sum(a * a for a in column)) or 1.0
        column[:] = [a / norm for a in column]


def embed(rows, vocabulary_size, dimensions=EMBEDDING_DIMENSIONS):
    """Truncated SVD by subspace iteration; returns one L2-normalised vector per row."""
    rng = random.Random(SEED)
    basis = [[rng.gauss(0, 1) for _ in range(vocabulary_size)] for _ in range(dimensions)]
    orthonormalize(basis)
    for _ in range(ITERATIONS):
        projected = [[sum(v * column[k] for k, v in row.items()) for row in rows] for column in basis]
        basis = []
        for column in projected:
            updated = [0.0] * vocabulary_size
            for value, row in zip(column, rows):
                for k, v in row.items():
                    updated[k] += value * v
            basis.append(updated)
        orthonormalize(basis)
    vectors = []
    for row in rows:
        vector = [sum(v * column[k] for k, v in row.items()) for column in basis]
        norm = math.sqrt(sum(a * a for a in vector)) or 1.0
        vectors.append([round(a / norm, 3) for a in vector])
    return vectors


def build_items(perks, addons):
    entries = []
    for perk in perks:
        entries.append(("perk", perk["id"], perk["name"], perk["role"], "", perk["description"]))
    for addon in addons:
        entries.append(("addon", addon["id"], addon["name"], addon["role"], addon["parent"], addon["description"]))
    rows, size = tf_idf([tokenize(body_of(e[5])) for e in entries])
    vectors = embed(rows, size)
    items = []
    for (kind, item_id, name, role, group, description), vector in zip(entries, vectors):
        produces, consumes, themes = extract_tags(name, description, is_addon=kind == "addon")
        items.append({"id": item_id, "kind": kind, "name": name, "role": role, "group": group,
                      "produces": produces, "consumes": consumes, "themes": themes, "embedding": vector})
    return items


def main():
    perks = json.loads((RESOURCES / "perks.json").read_text())["perks"]
    addons = json.loads((RESOURCES / "addons.json").read_text())["addons"]
    items = build_items(perks, addons)
    document = {"schemaVersion": SCHEMA_VERSION, "dimensions": EMBEDDING_DIMENSIONS, "items": items}
    OUTPUT.write_text(json.dumps(document, separators=(",", ":"), ensure_ascii=False))
    tagged = sum(1 for i in items if i["produces"] or i["consumes"])
    print(f"{len(items)} items, {tagged} with producer/consumer tags -> {OUTPUT} ({OUTPUT.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
