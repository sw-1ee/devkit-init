#!/usr/bin/env python3
"""normalize.py — _raw/ 원본 → references/ 정규화 산출.

결정적 변환만 수행 (LLM 없음):
  ui-ux-pro-max CSV 6종      → references/design-rules/*.json
  VoltAgent DESIGN.md 트리    → references/design-systems/<slug>/DESIGN.md + index.json
  impeccable antipatterns.mjs → references/anti-slop/rules.json (node 로 JS 배열 추출)
  hallmark SKILL.md/references → references/anti-slop/ 원본 보존 (20테마·게이트 = 프로즈, 파싱 안 함)
  bencium a11y/motion         → references/a11y-motion/ 원본 보존
"""
import csv, json, shutil, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = HERE.parent / "_raw"
REF = HERE.parent / "references"


def norm_key(s: str) -> str:
    return s.strip().lower().replace(" ", "-")


def load_csv(path: Path):
    with open(path, newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def parse_embedded_json(s: str):
    s = (s or "").strip()
    if s.startswith("{"):
        try:
            return json.loads(s)
        except json.JSONDecodeError:
            pass
    return s or None


def do_design_rules():
    src = RAW / "ui-ux-pro-max" / "data"
    out = REF / "design-rules"
    out.mkdir(parents=True, exist_ok=True)

    # industry-rules.json ← ui-reasoning.csv (Decision_Rules 임베드 JSON 파싱)
    rows = load_csv(src / "ui-reasoning.csv")
    rules = [{
        "id": int(r["No"]),
        "industry": r["UI_Category"],
        "pattern": r["Recommended_Pattern"],
        "style_priority": [x.strip() for x in r["Style_Priority"].split("+")],
        "color_mood": r["Color_Mood"],
        "typography_mood": r["Typography_Mood"],
        "effects": [x.strip() for x in r["Key_Effects"].split("+")],
        "decision_rules": parse_embedded_json(r["Decision_Rules"]),
        "anti_patterns": [x.strip() for x in r["Anti_Patterns"].split("+")],
        "severity": r["Severity"],
        "source": "ui-ux-pro-max",
    } for r in rows]
    (out / "industry-rules.json").write_text(
        json.dumps(rules, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"  design-rules/industry-rules.json: {len(rules)}")

    # palettes.json ← colors.csv (shadcn 토큰 세트)
    rows = load_csv(src / "colors.csv")
    token_cols = [c for c in rows[0].keys() if c not in ("No", "Product Type", "Notes")]
    palettes = [{
        "id": int(r["No"]),
        "industry": r["Product Type"],
        "tokens": {norm_key(c): r[c] for c in token_cols},
        "notes": r.get("Notes", ""),
        "source": "ui-ux-pro-max",
    } for r in rows]
    (out / "palettes.json").write_text(
        json.dumps(palettes, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"  design-rules/palettes.json: {len(palettes)} (tokens/row: {len(token_cols)})")

    # 나머지 4종은 컬럼 그대로 JSON 화 (스키마 소스별 상이 — 원형 유지가 정직)
    for name in ("typography", "ux-guidelines", "charts", "styles"):
        rows = load_csv(src / f"{name}.csv")
        data = [{norm_key(k): v for k, v in r.items()} | {"source": "ui-ux-pro-max"}
                for r in rows]
        (out / f"{name}.json").write_text(
            json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"  design-rules/{name}.json: {len(data)}")


def do_design_systems():
    src = RAW / "design-systems" / "systems"
    out = REF / "design-systems"
    out.mkdir(parents=True, exist_ok=True)
    index = []
    for d in sorted(src.iterdir()):
        f = d / "DESIGN.md"
        if not f.is_file():
            continue
        dst = out / d.name
        dst.mkdir(exist_ok=True)
        shutil.copy(f, dst / "DESIGN.md")
        first = f.read_text(encoding="utf-8", errors="replace").lstrip().splitlines()
        title = first[0].lstrip("# ").strip() if first else d.name
        index.append({"slug": d.name, "title": title,
                      "file": f"design-systems/{d.name}/DESIGN.md",
                      "source": "VoltAgent/awesome-design-md"})
    (out / "index.json").write_text(json.dumps(index, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"  design-systems: {len(index)} brands + index.json")


def do_anti_slop():
    out = REF / "anti-slop"
    out.mkdir(parents=True, exist_ok=True)

    # impeccable 45룰: node 로 mjs 모듈 import → JSON
    mjs = RAW / "impeccable" / "src" / "registry" / "antipatterns.mjs"
    js = f"import('{mjs}').then(m => console.log(JSON.stringify(m.ANTIPATTERNS ?? m.default)))"
    res = subprocess.run(["node", "-e", js], capture_output=True, text=True, check=True)
    rules = json.loads(res.stdout)
    for r in rules:
        r["source"] = "pbakaus/impeccable"
    (out / "rules.json").write_text(json.dumps(rules, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"  anti-slop/rules.json: {len(rules)}")

    # hallmark: 원본 보존 (20테마+게이트 = 프로즈. 브리틀한 파싱 대신 원문 참조)
    shutil.copy(RAW / "hallmark" / "SKILL.md", out / "hallmark-SKILL.md")
    hall_ref = RAW / "hallmark" / "references"
    if hall_ref.is_dir():
        shutil.copytree(hall_ref, out / "hallmark-references", dirs_exist_ok=True)
    print("  anti-slop/hallmark-SKILL.md + references (원본 보존)")


def do_a11y_motion():
    out = REF / "a11y-motion"
    out.mkdir(parents=True, exist_ok=True)
    for f in ("ACCESSIBILITY.md", "MOTION-SPEC.md"):
        shutil.copy(RAW / "bencium" / f, out / f)
    print("  a11y-motion/: bencium controlled 2종 (원본 보존)")


if __name__ == "__main__":
    do_design_rules()
    do_design_systems()
    do_anti_slop()
    do_a11y_motion()
    print("normalize complete.")
