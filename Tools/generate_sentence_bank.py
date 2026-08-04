#!/usr/bin/env python3
"""
=============================================================================
SUPERSEDED — DO NOT RUN. This will OVERWRITE hand-reviewed sentences.
=============================================================================

SentenceBank.json was seeded by this script and has since been reviewed and
corrected by hand. Roughly 180 entries were deleted and 20 edited to fix
problems templates could not express: number/noun agreement ("There are one
students"), verb stacking ("He wants to want"), preposition errors ("Who goes
to home?", "works at class"), first-person questions inside greetings ("Hello,
am I a student?"), wrong-tense idioms ("I see you later"), verbs missing a
required argument ("He tells my name"), and JOB used as a place you travel to.

Running this script would regenerate from the templates and discard every one
of those fixes.

**SentenceBank.json is now the source of truth.** To change the bank, edit the
JSON and re-run Tools/validate_sentence_bank.swift. Keep this file only as a
record of how the seed corpus was built, and as a starting point if the bank is
ever rebuilt from scratch — in which case fold the corrections above back into
the templates first.

-----------------------------------------------------------------------------
Original description follows.

Generated Talking Fingers/Resources/SentenceBank.json.

See ON_DEVICE_SENTENCE_GENERATION_PLAN.md §4.2/§4.5. Every sentence is owned by
exactly one category and draws its gloss only from
`owningCategory ∪ personalInformation`, which is the invariant the runtime
selection relies on.

Vocabulary is parsed straight out of Term.swift (comments stripped, backticked
keyword cases handled) so this can never drift from the app's real Term enum.
Templates are expanded over that vocabulary and sampled, which buys volume with
guaranteed-valid tokens; it does NOT buy idiomatic ASL. Run
Tools/validate_sentence_bank.swift afterwards, and have the output spot-checked
by someone who signs before treating it as final.

Usage (from the repo root):
    python3 Tools/generate_sentence_bank.py
"""

import json
import random
import re
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TERM_SWIFT = REPO / "Talking Fingers/Flashcards/Models/Term.swift"
OUT = REPO / "Talking Fingers/Resources/SentenceBank.json"

TARGET_PER_CATEGORY = 320
SEED = 20260729


# --------------------------------------------------------------------------
# Parse Term.swift
# --------------------------------------------------------------------------

def parse_terms():
    """Returns (raw_by_case, category_by_raw) from the live (uncommented) enum."""
    src = TERM_SWIFT.read_text()
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    src = "\n".join(re.sub(r"//.*$", "", line) for line in src.split("\n"))

    enum_src = src[src.index("enum Term:"):]
    raw_by_case = {
        case: raw
        for case, raw in re.findall(r"\bcase\s+`?(\w+)`?\s*=\s*\"([^\"]+)\"", enum_src)
    }

    # `var category: TermCategory { switch self { case .a, .b: return .x ... } }`
    cat_block = re.search(r"var category: TermCategory \{(.*?)\n    \}", src, re.S).group(1)
    category_by_raw = {}
    for cases, category in re.findall(
        r"case\s+((?:\.\s*`?\w+`?\s*,?\s*)+):\s*\n?\s*return\s+\.(\w+)", cat_block
    ):
        for case in re.findall(r"\.\s*`?(\w+)`?", cases):
            if case in raw_by_case:
                category_by_raw[raw_by_case[case]] = category

    return raw_by_case, category_by_raw


RAW_BY_CASE, CATEGORY_BY_RAW = parse_terms()
BY_CATEGORY = defaultdict(list)
for raw, category in CATEGORY_BY_RAW.items():
    BY_CATEGORY[category].append(raw)

# Swift enum case name -> TermCategory rawValue used in the JSON.
CATEGORY_RAW_VALUE = {
    "alphabet": "alphabet",
    "numbers": "numbers",
    "greetings": "greetings",
    "personalInformation": "personal information",
    "family": "family",
    "verbs": "verbs",
    "locations": "locations",
}

PI = set(BY_CATEGORY["personalInformation"])


# --------------------------------------------------------------------------
# English lexicon
# --------------------------------------------------------------------------

SUBJECTS = [
    # gloss, english, third-person?
    ("ME", "I", False),
    ("YOU", "you", False),
    ("HE", "he", True),
    ("SHE", "she", True),
    ("WE", "we", False),
    ("THEY", "they", False),
]

POSSESSIVES = [
    ("MY", "my"), ("YOUR", "your"), ("HIS", "his"),
    ("HER", "her"), ("OUR", "our"), ("THEIR", "their"),
]

SUBJECT_GLOSS = {gloss for gloss, _, _ in SUBJECTS}
POSSESSIVE_GLOSS = {gloss for gloss, _ in POSSESSIVES}

# A person has one name, so a plural possessor reads wrong against it —
# "our name is Amy", "he likes our name". Use this wherever NAME is the noun.
NAME_POSSESSIVES = [(g, e) for g, e in POSSESSIVES if g != "OUR"]

THIRD_PERSON = {
    "GO": "goes", "COME": "comes", "WANT": "wants", "EAT": "eats", "DRINK": "drinks",
    "STUDY": "studies", "FINISH": "finishes", "HELP": "helps", "PLAY": "plays",
    "WATCH": "watches", "LEARN": "learns", "TEACH": "teaches", "VISIT": "visits",
    "TALK": "talks", "MAKE": "makes", "TAKE": "takes", "GIVE": "gives", "GET": "gets",
    "KNOW": "knows", "THINK": "thinks", "FEEL": "feels", "SAY": "says", "TELL": "tells",
    "SEE": "sees", "LIKE": "likes", "LIVE": "lives", "WORK": "works",
}

# Locations rendered as the object of "go to".
GO_TO = {
    "HOME": "home", "SCHOOL": "school", "COLLEGE": "college", "CLASS": "class",
    "JOB": "the job", "OFFICE": "the office", "STORE": "the store",
    "HOSPITAL": "the hospital", "RESTAURANT": "the restaurant",
    "LIBRARY": "the library", "PARK": "the park",
}
# "goes home" takes no preposition; the rest take "to".
NO_PREPOSITION = {"HOME"}

RELATIVE_EN = {
    "MOTHER": "mother", "FATHER": "father", "MOM": "mom", "DAD": "dad",
    "SISTER": "sister", "BROTHER": "brother", "GRANDMOTHER": "grandmother",
    "GRANDFATHER": "grandfather", "HUSBAND": "husband", "WIFE": "wife",
    "CHILD": "child", "SON": "son", "DAUGHTER": "daughter", "FAMILY": "family",
}

NUMBER_EN = {
    "0": "zero", "1": "one", "2": "two", "3": "three", "4": "four", "5": "five",
    "6": "six", "7": "seven", "8": "eight", "9": "nine", "10": "ten",
    "15": "fifteen", "20": "twenty", "100": "one hundred",
}

NAMES = [
    "JOHN", "AMY", "BEN", "KATE", "LUIS", "MIA", "NOAH", "OLIVIA", "SAM",
    "TARA", "ZOE", "ERIC", "IAN", "LILY", "MAX", "NINA", "OSCAR", "PAUL",
    "RUTH", "TOM", "ANNA", "DAVID", "ELLA", "FINN", "GRACE", "HUGO",
    "IRIS", "JADE", "KEVIN", "LEO", "MAYA", "NORA", "OWEN", "PEDRO",
    "QUINN", "ROSA", "SOFIA", "THEO", "UMA", "VERA", "WYATT", "YARA",
    "ADAM", "BELLA", "CARLOS", "DIEGO", "EVAN", "FIONA", "GABE", "HANNAH",
]


def verb_en(gloss, third_person):
    if third_person:
        return THIRD_PERSON.get(gloss, gloss.lower() + "s")
    return gloss.lower()


# --------------------------------------------------------------------------
# Template expansion
# --------------------------------------------------------------------------

class Bank:
    def __init__(self):
        self.by_category = defaultdict(list)
        self.seen_english = set()
        self.seen_gloss = set()

    def add(self, category, english, gloss):
        gloss = [t for t in gloss if t]
        allowed = set(BY_CATEGORY[category]) | PI
        if any(t not in allowed for t in gloss):
            return
        # A possessive must be followed by the thing it owns. Templates that
        # drop the noun (because it fell outside the category's scope) leave a
        # dangling MY/HER/THEIR — reject rather than ship "SHE LIKE HER".
        if gloss[-1] in POSSESSIVE_GLOSS:
            return
        # Reject anything that is only pronouns and possessives — no content.
        if all(t in POSSESSIVE_GLOSS or t in SUBJECT_GLOSS for t in gloss):
            return
        english = english[0].upper() + english[1:]
        gloss_key = " ".join(gloss)
        if english.lower() in self.seen_english or gloss_key in self.seen_gloss:
            return
        self.seen_english.add(english.lower())
        self.seen_gloss.add(gloss_key)
        self.by_category[category].append({"english": english, "gloss": gloss})


bank = Bank()
rng = random.Random(SEED)


def verbs_for(category):
    """Verbs usable inside a category's own scope (its verbs plus PI's)."""
    pool = [v for v in BY_CATEGORY[category] if v in THIRD_PERSON]
    pool += [v for v in PI if v in THIRD_PERSON]
    return sorted(set(pool))


# ---- family --------------------------------------------------------------

relatives = [r for r in BY_CATEGORY["family"] if r in RELATIVE_EN and r != "FAMILY"]

# "our mother" is fine (siblings share one); "our husband" is not. Spouses are
# the one relation a plural possessor can't share.
NOT_SHARED = {"HUSBAND", "WIFE"}

for poss, poss_en in POSSESSIVES:
    for rel in relatives:
        if poss == "OUR" and rel in NOT_SHARED:
            continue
        rel_en = RELATIVE_EN[rel]
        bank.add("family", f"{poss_en} {rel_en} is a student.", [poss, rel, "STUDENT"])
        bank.add("family", f"{poss_en} {rel_en} works.", [poss, rel, "WORK"])
        bank.add("family", f"I like {poss_en} {rel_en}.", ["ME", "LIKE", poss, rel])
        bank.add("family", f"Who is {poss_en} {rel_en}?", [poss, rel, "WHO"])
        bank.add("family", f"What is {poss_en} {rel_en}'s name?", [poss, rel, "NAME", "WHAT"])
        bank.add("family", f"Where does {poss_en} {rel_en} live?", [poss, rel, "LIVE", "WHERE"])
        for subj, subj_en, third in SUBJECTS:
            bank.add("family", f"{subj_en} know {poss_en} {rel_en}." if not third
                     else f"{subj_en} knows {poss_en} {rel_en}.",
                     [subj, "KNOW", poss, rel])

# ---- locations -----------------------------------------------------------

places = [p for p in BY_CATEGORY["locations"] if p in GO_TO]
for subj, subj_en, third in SUBJECTS:
    for place in places:
        place_en = GO_TO[place]
        prep = "" if place in NO_PREPOSITION else "to "
        bank.add("locations", f"{subj_en} {verb_en('GO', third)} {prep}{place_en}.",
                 [subj, "GO", place])
        bank.add("locations", f"{subj_en} {verb_en('LIKE', third)} {place_en}.",
                 [subj, "LIKE", place])
        bank.add("locations", f"{subj_en} {verb_en('WORK', third)} at {place_en}.",
                 [subj, "WORK", place])
    for poss, poss_en in POSSESSIVES:
        for place in places:
            bank.add("locations", f"{poss_en} favorite place is {GO_TO[place]}.",
                     [poss, "FAVORITE", place])
for place in places:
    bank.add("locations", f"Where is {GO_TO[place]}?", [place, "WHERE"])
    bank.add("locations", f"Who goes to {GO_TO[place]}?", [place, "GO", "WHO"])

# ---- verbs ---------------------------------------------------------------

action_verbs = sorted(set(BY_CATEGORY["verbs"]) & set(THIRD_PERSON))

# Verbs that need a direct object to read naturally. "I want to make.",
# "We like to tell.", "He gives." are all incomplete.
#
# There is nothing to give them: the only noun-bearing categories in
# SentenceGenerationService.allowedCategories are family, locations and
# personal information — commonObjects (FOOD, WATER, BOOK...) is excluded, so
# a verbs-owned sentence has no object vocabulary in scope. Rather than ship
# "I want to make.", these verbs are simply left out of the objectless
# templates. See the note in §4.5 of the plan.
NEEDS_OBJECT = {"MAKE", "TAKE", "GIVE", "GET", "TELL", "SAY", "FEEL"}

# Verbs that don't read as a teachable skill ("She knows how to know").
NOT_A_LEARNABLE_SKILL = NEEDS_OBJECT | {"KNOW", "THINK", "WANT"}

for subj, subj_en, third in SUBJECTS:
    for verb in action_verbs:
        if verb not in NEEDS_OBJECT:
            bank.add("verbs", f"{subj_en} {verb_en(verb, third)}.", [subj, verb])
            bank.add("verbs", f"{subj_en} {verb_en('WANT', third)} to {verb.lower()}.",
                     [subj, "WANT", verb])
            bank.add("verbs", f"{subj_en} {verb_en('LIKE', third)} to {verb.lower()}.",
                     [subj, "LIKE", verb])
            bank.add("verbs", f"Who will {verb.lower()}?", [verb, "WHO"])
        if verb not in NOT_A_LEARNABLE_SKILL:
            bank.add("verbs", f"{subj_en} {verb_en('KNOW', third)} how to {verb.lower()}.",
                     [subj, "KNOW", verb, "HOW"])

    # Give the object-hungry verbs the one object that IS in scope, so they
    # aren't absent from the bank entirely.
    for poss, poss_en in NAME_POSSESSIVES:
        bank.add("verbs", f"{subj_en} {verb_en('SAY', third)} {poss_en} name.",
                 [subj, "SAY", poss, "NAME"])
        bank.add("verbs", f"{subj_en} {verb_en('KNOW', third)} {poss_en} name.",
                 [subj, "KNOW", poss, "NAME"])
        bank.add("verbs", f"{subj_en} {verb_en('TELL', third)} {poss_en} name.",
                 [subj, "TELL", poss, "NAME"])

# ---- shared question-word clauses ----------------------------------------
# Both greetings and personal information are vocabulary-poor on their own, so
# they lean on PI's pronouns, four verbs (LIVE/WORK/LIKE/GO) and question words
# for volume. ASL puts the question word last — see the glossing rules.

# Which question words each intransitive verb actually takes. A flat
# verb x question cross-product produced nonsense ("when does he live?",
# "why do you like?"), so the pairings are enumerated instead.
#
# LIKE is absent on purpose: it is transitive, so "do you like?" and
# "why does he like?" have no object. It only appears in templates that
# supply one (LIKE + noun).
PI_VERB_QUESTIONS = {
    "LIVE": [("WHERE", "where")],
    "WORK": [("WHERE", "where"), ("WHEN", "when"), ("WHY", "why")],
    "GO": [("WHERE", "where"), ("WHEN", "when"), ("WHY", "why")],
}
PI_VERB_EN = {"LIVE": "live", "WORK": "work", "GO": "go"}

# LIVE is excluded from the bare "does X live?" form — as a yes/no question it
# asks something nobody asks. It still appears with WHERE.
PI_BARE_VERBS = {"WORK": "work", "GO": "go"}

# "are we a student" is wrong; plural subjects need a plural complement.
PLURAL_SUBJECTS = {"WE", "THEY"}


def pi_clauses():
    """(english, gloss) fragments built only from personal-information terms."""
    out = []
    for subj, subj_en, third in SUBJECTS:
        does = "does" if third else "do"
        for verb, verb_base in PI_BARE_VERBS.items():
            out.append((f"{does} {subj_en} {verb_base}", [subj, verb]))
        for verb, verb_base in PI_VERB_EN.items():
            for qgloss, qen in PI_VERB_QUESTIONS[verb]:
                out.append((f"{qen} {does} {subj_en} {verb_base}", [subj, verb, qgloss]))

        is_are = "is" if third else ("am" if subj == "ME" else "are")
        student = "students" if subj in PLURAL_SUBJECTS else "a student"
        out.append((f"{is_are} {subj_en} {student}", [subj, "STUDENT"]))
        out.append((f"where {is_are} {subj_en} from", [subj, "FROM", "WHERE"]))
        out.append((f"who {is_are} {subj_en}", [subj, "WHO"]))

    for poss, poss_en in POSSESSIVES:
        if (poss, poss_en) in NAME_POSSESSIVES:
            out.append((f"what is {poss_en} name", [poss, "NAME", "WHAT"]))
        out.append((f"what is {poss_en} age", [poss, "AGE", "WHAT"]))
        out.append((f"what is {poss_en} favorite work", [poss, "FAVORITE", "WORK", "WHAT"]))
        # "where does my family live" was dropped: FAMILY is not a
        # personal-information term, so the English named a word the gloss
        # could not carry.
    return out


PI_CLAUSES = pi_clauses()

# ---- greetings -----------------------------------------------------------

greetings_terms = set(BY_CATEGORY["greetings"])
time_words = [t for t in ("MORNING", "AFTERNOON", "EVENING", "NIGHT") if t in greetings_terms]

# Openers are split by whether a question can naturally follow. "Bye, where
# do you live?" and "Sorry, are you a student?" read as non-sequiturs — a
# farewell or an apology does not introduce a question — so only the greeting
# openers get crossed with the question clauses.
greeting_openers = []
if "HELLO" in greetings_terms:
    greeting_openers.append(("Hello", ["HELLO"]))
if "HI" in greetings_terms:
    greeting_openers.append(("Hi", ["HI"]))
for time_word in time_words:
    if time_word == "NIGHT":
        continue  # "Good night" is a farewell — handled below
    greeting_openers.append((f"Good {time_word.lower()}", ["GOOD", time_word]))

farewell_openers = []
if "BYE" in greetings_terms:
    farewell_openers.append(("Bye", ["BYE"]))
if "NIGHT" in greetings_terms:
    farewell_openers.append(("Good night", ["GOOD", "NIGHT"]))

# The question word goes last, per the glossing rules the app teaches. That
# rules out the idiomatic "HOW YOU" / "WHAT UP" orderings — a learner shouldn't
# meet a rule in the prompt and counterexamples in the bank.
greeting_followons = [
    ("how are you?", ["YOU", "HOW"]),
    ("nice to meet you.", ["NICE", "MEET", "YOU"]),
    ("what is your name?", ["YOUR", "NAME", "WHAT"]),
]
farewell_followons = [
    ("see you later.", ["SEE", "YOU", "LATER"]),
    ("good night.", ["GOOD", "NIGHT"]),
]

for opener_en, opener_gloss in greeting_openers:
    bank.add("greetings", f"{opener_en}.", opener_gloss)
    for follow_en, follow_gloss in greeting_followons:
        bank.add("greetings", f"{opener_en}, {follow_en}", opener_gloss + follow_gloss)
    for clause_en, clause_gloss in PI_CLAUSES:
        bank.add("greetings", f"{opener_en}, {clause_en}?", opener_gloss + clause_gloss)

for opener_en, opener_gloss in farewell_openers:
    bank.add("greetings", f"{opener_en}.", opener_gloss)
    for follow_en, follow_gloss in farewell_followons:
        if follow_gloss == opener_gloss:
            continue  # no "Good night, good night."
        bank.add("greetings", f"{opener_en}, {follow_en}", opener_gloss + follow_gloss)

if "SORRY" in greetings_terms:
    bank.add("greetings", "Sorry.", ["SORRY"])
    bank.add("greetings", "Sorry, see you later.", ["SORRY", "SEE", "YOU", "LATER"])

for follow_en, follow_gloss in greeting_followons + farewell_followons:
    bank.add("greetings", follow_en.capitalize(), follow_gloss)
for subj, subj_en, third in SUBJECTS:
    bank.add("greetings", f"{subj_en} {verb_en('SEE', third)} you later.",
             [subj, "SEE", "YOU", "LATER"])
    bank.add("greetings", f"{subj_en} {verb_en('MEET', third) if third else 'meet'} you later.",
             [subj, "MEET", "YOU", "LATER"])
    bank.add("greetings", f"How {'is' if third else 'are'} {subj_en}?", [subj, "HOW"])

# ---- personal information ------------------------------------------------

for clause_en, clause_gloss in PI_CLAUSES:
    bank.add("personalInformation", f"{clause_en}?", clause_gloss)

# Only the intransitive verbs stand alone. LIKE is excluded here for the same
# reason it takes no question clause — "He likes." has no object.
for subj, subj_en, third in SUBJECTS:
    for verb in PI_VERB_EN:
        bank.add("personalInformation", f"{subj_en} {verb_en(verb, third)}.", [subj, verb])
    for poss, poss_en in NAME_POSSESSIVES:
        bank.add("personalInformation", f"{subj_en} {verb_en('LIKE', third)} {poss_en} name.",
                 [subj, "LIKE", poss, "NAME"])
        bank.add("personalInformation", f"{subj_en} {verb_en('LIKE', third)} {poss_en} work.",
                 [subj, "LIKE", poss, "WORK"])
        bank.add("personalInformation", f"{subj_en} {verb_en('GO', third)} to {poss_en} work.",
                 [subj, "GO", poss, "WORK"])

for poss, poss_en in POSSESSIVES:
    bank.add("personalInformation", f"Who is {poss_en} student?", [poss, "STUDENT", "WHO"])
    bank.add("personalInformation", f"Where is {poss_en} work?", [poss, "WORK", "WHERE"])
    bank.add("personalInformation", f"When does {poss_en} student go?", [poss, "STUDENT", "GO", "WHEN"])
    bank.add("personalInformation", f"Why does {poss_en} student work?", [poss, "STUDENT", "WORK", "WHY"])

# ---- alphabet ------------------------------------------------------------

letters = set(BY_CATEGORY["alphabet"])
for name in NAMES:
    if not all(ch in letters for ch in name):
        continue
    spelled = list(name)
    pretty = name.capitalize()
    # OUR is excluded: "Our name is Amy" is a plural possessor with a singular
    # name. The rest read naturally, including singular "their".
    for poss, poss_en in NAME_POSSESSIVES:
        bank.add("alphabet", f"{poss_en.capitalize()} name is {pretty}.", [poss, "NAME"] + spelled)
    bank.add("alphabet", f"Who is {pretty}?", spelled + ["WHO"])
    bank.add("alphabet", f"I know {pretty}.", ["ME", "KNOW"] + spelled)
    # Yes/no questions carry no question word in ASL — they're marked by facial
    # grammar — so this must not append WHO the way a wh-question does.
    bank.add("alphabet", f"Do you know {pretty}?", ["YOU", "KNOW"] + spelled)

# ---- numbers -------------------------------------------------------------

numbers = [n for n in BY_CATEGORY["numbers"] if n in NUMBER_EN]
for poss, poss_en in POSSESSIVES:
    for number in numbers:
        bank.add("numbers", f"{poss_en.capitalize()} age is {NUMBER_EN[number]}.",
                 [poss, "AGE", number])
# Age is stated with the possessive ("MY AGE FIVE"), never the subject form.
# "ME AGE" is exactly the ME/MY confusion this app teaches against, so the
# subject-pronoun variant is deliberately not generated.
for poss, poss_en in POSSESSIVES:
    bank.add("numbers", f"What is {poss_en} age?", [poss, "AGE", "WHAT"])
    for number in numbers:
        bank.add("numbers", f"{poss_en.capitalize()} favorite number is {NUMBER_EN[number]}.",
                 [poss, "FAVORITE", number])
for subj, subj_en, third in SUBJECTS:
    for number in numbers:
        bank.add("numbers", f"{subj_en.capitalize()} {verb_en('LIKE', third)} the number {NUMBER_EN[number]}.",
                 [subj, "LIKE", number])
        bank.add("numbers", f"{subj_en.capitalize()} {verb_en('WORK', third)} with {NUMBER_EN[number]} students.",
                 [subj, "WORK", number, "STUDENT"])
for number in numbers:
    bank.add("numbers", f"There are {NUMBER_EN[number]} students.", [number, "STUDENT"])
    bank.add("numbers", f"Who is {NUMBER_EN[number]} years old?", [number, "AGE", "WHO"])


# --------------------------------------------------------------------------
# Sample, id, write
# --------------------------------------------------------------------------

sentences = []
report = []
for category in CATEGORY_RAW_VALUE:
    pool = bank.by_category[category]
    rng.shuffle(pool)
    chosen = pool[:TARGET_PER_CATEGORY]
    chosen.sort(key=lambda s: (len(s["gloss"]), s["english"]))
    # The id prefix is the category's TermCategory rawValue with spaces
    # hyphenated — "personal information" -> "personal-information-0001".
    id_prefix = CATEGORY_RAW_VALUE[category].replace(" ", "-")
    for index, entry in enumerate(chosen, start=1):
        sentences.append({
            "id": f"{id_prefix}-{index:04d}",
            "english": entry["english"],
            "gloss": entry["gloss"],
            "category": CATEGORY_RAW_VALUE[category],
        })
    report.append((category, len(chosen), len(pool)))

OUT.write_text(json.dumps({"version": 1, "sentences": sentences}, indent=2) + "\n")

print(f"wrote {len(sentences)} sentences to {OUT.relative_to(REPO)}")
for category, kept, available in report:
    flag = "" if kept >= 200 else "   <-- below the 200 target"
    print(f"  {category:22} {kept:4}  (of {available} generated){flag}")
