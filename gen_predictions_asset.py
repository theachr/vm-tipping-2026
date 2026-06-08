#!/usr/bin/env python3
"""Bygg app-ressurs (assets/data/predictions.json) frå alle deltakarar i participants/.
Kvar fil participants/*.json har forma {"name", "tips": {rad: {kamp, score}}, "medaljer": {gull, solv, bronse}}.
Mapper norske lagnamn -> openfootball engelske namn, lagrar tippa mål per lag, og
validerer at alle gruppekampar finst i den offisielle openfootball-dataen."""
import json, sys, os, glob, urllib.request

BASE = os.path.dirname(os.path.abspath(__file__))
PARTICIPANTS_DIR = os.path.join(BASE, "participants")
OUT  = os.path.join(BASE, "vm_tracker", "assets", "data", "predictions.json")
WC_URL = "https://raw.githubusercontent.com/openfootball/worldcup.json/master/2026/worldcup.json"
WC_CACHE = "/tmp/wc2026.json"

NO2EN = {
    "Mexico":"Mexico","Sør-Afrika":"South Africa","Sør-Korea":"South Korea","Tsjekkia":"Czech Republic",
    "Canada":"Canada","Sveits":"Switzerland","Bosnia-Hercegovina":"Bosnia & Herzegovina","Qatar":"Qatar",
    "USA":"USA","Paraguay":"Paraguay","Australia":"Australia","Tyrkia":"Turkey",
    "Brasil":"Brazil","Marokko":"Morocco","Skottland":"Scotland","Haiti":"Haiti",
    "Tyskland":"Germany","Ecuador":"Ecuador","Elfenbenskysten":"Ivory Coast","Curaçao":"Curaçao",
    "Nederland":"Netherlands","Japan":"Japan","Sverige":"Sweden","Tunisia":"Tunisia",
    "Spania":"Spain","Uruguay":"Uruguay","Saudi Arabia":"Saudi Arabia","Kapp Verde":"Cape Verde",
    "Belgia":"Belgium","Iran":"Iran","Egypt":"Egypt","New Zealand":"New Zealand",
    "Frankrike":"France","Norge":"Norway","Senegal":"Senegal","Irak":"Iraq",
    "Argentina":"Argentina","Østerrike":"Austria","Algerie":"Algeria","Jordan":"Jordan",
    "Portugal":"Portugal","Colombia":"Colombia","Usbekistan":"Uzbekistan","DR Kongo":"DR Congo",
    "England":"England","Kroatia":"Croatia","Ghana":"Ghana","Panama":"Panama",
}

def en(no_name):
    n = no_name.strip()
    if n not in NO2EN:
        raise KeyError(f"Manglar mapping for norsk lagnamn: {n!r}")
    return NO2EN[n]

def load_official():
    if not os.path.exists(WC_CACHE):
        urllib.request.urlretrieve(WC_URL, WC_CACHE)
    d = json.load(open(WC_CACHE, encoding="utf-8"))
    pairs = set()
    for m in d["matches"]:
        if (m.get("group") or "").startswith("Group"):
            pairs.add(frozenset([m["team1"], m["team2"]]))
    return pairs

def build_participant(src, official, errors):
    name = src.get("name", "Ukjend")
    out_preds = []
    for row, info in src["tips"].items():
        no_a, no_b = [x.strip() for x in info["kamp"].split("–")]
        ga, gb = [int(x) for x in info["score"].split("-")]
        ea, eb = en(no_a), en(no_b)
        key = frozenset([ea, eb])
        if key not in official:
            errors.append(f"{name} rad {row}: {ea} vs {eb} finst IKKJE i offisielle gruppekampar")
        out_preds.append({"teams": sorted([ea, eb]), "goals": {ea: ga, eb: gb}})
    m = src["medaljer"]
    return {
        "name": name,
        "medals": {"gold": en(m["gull"]), "silver": en(m["solv"]), "bronze": en(m["bronse"])},
        "predictions": out_preds,
    }

def main():
    official = load_official()
    files = sorted(glob.glob(os.path.join(PARTICIPANTS_DIR, "*.json")))
    if not files:
        print(f"Ingen deltakarfiler i {PARTICIPANTS_DIR}")
        sys.exit(1)
    participants, errors = [], []
    for f in files:
        src = json.load(open(f, encoding="utf-8"))
        participants.append(build_participant(src, official, errors))
    if errors:
        print("VALIDERINGSFEIL:")
        for e in errors: print("  -", e)
        sys.exit(1)
    out = {
        "source": WC_URL,
        "rules": {"exact": 3, "correct_winner": 1, "medal_correct": 3, "medal_team_wrong_place": 1},
        "participants": participants,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    names = ", ".join(p["name"] for p in participants)
    print(f"OK: skreiv {len(participants)} deltakarar ({names}) til {OUT}")
    for p in participants:
        print(f"  - {p['name']}: {len(p['predictions'])} gruppekampar matcha offisiell data")

if __name__ == "__main__":
    main()
