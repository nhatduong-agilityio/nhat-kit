"""Structural check of devkit's GitHub issue forms, after simulating bootstrap's fill step."""
import re, sys, yaml

D = "/Users/nhat.duongasnet/Documents/training/claude-kit/plugins/devkit/templates/github/ISSUE_TEMPLATE/"
TYPES = {"markdown", "input", "textarea", "dropdown", "checkboxes"}
REQUIRED = {"bug.yml": {"where", "steps", "expected", "actual", "severity"},
            "feature.yml": {"problem", "proposal", "acceptance"}}
fail = []

def strip_comments(text):  # bootstrap deletes every "# TEMPLATE:" comment line
    return re.sub(r"(?m)^ *# TEMPLATE:.*\n", "", text)

def fill(text):        # bootstrap with areas: one option line per area
    return strip_comments(text.replace("        - {{AREAS}}", "        - web\n        - api"))

def drop_area(text):   # bootstrap without areas: delete the comment and the field
    return re.sub(r"  # TEMPLATE:.*\n  - type: dropdown\n    id: area\n(    .*\n|      .*\n|        .*\n)*", "", text)

def check(name, text, variant):
    if "{{" in text or "TEMPLATE" in text:
        fail.append(f"{name}/{variant}: leftover placeholder")
    form = yaml.safe_load(text)
    for key in ("name", "description", "body"):
        if key not in form:
            fail.append(f"{name}/{variant}: missing top-level {key}")
    ids = set()
    for i, item in enumerate(form["body"]):
        t = item.get("type")
        if t not in TYPES:
            fail.append(f"{name}/{variant}: body[{i}] bad type {t}")
        attrs = item.get("attributes") or {}
        if t == "markdown":
            if "value" not in attrs:
                fail.append(f"{name}/{variant}: markdown without value")
            continue
        if "id" not in item or item["id"] in ids:
            fail.append(f"{name}/{variant}: body[{i}] missing or duplicate id")
        ids.add(item.get("id"))
        if not attrs.get("label"):
            fail.append(f"{name}/{variant}: {item.get('id')} without label")
        if t == "dropdown" and not attrs.get("options"):
            fail.append(f"{name}/{variant}: dropdown {item['id']} without options")
        if item.get("id") in REQUIRED[name] and not (item.get("validations") or {}).get("required"):
            fail.append(f"{name}/{variant}: {item['id']} should be required")
    missing = REQUIRED[name] - ids
    if missing:
        fail.append(f"{name}/{variant}: required fields missing: {missing}")
    return ids

for name in REQUIRED:
    raw = open(D + name).read()
    if "{{AREAS}}" not in raw:
        fail.append(f"{name}: no {{AREAS}} placeholder")
    a = check(name, fill(raw), "filled")
    b = check(name, drop_area(raw), "no-areas")
    if "area" not in a or "area" in b:
        fail.append(f"{name}: area field fill/delete simulation wrong")
    print(f"{name}: filled ids={sorted(a)}; no-areas ids={sorted(b)}")

cfg = yaml.safe_load(open(D + "config.yml"))
if cfg.get("blank_issues_enabled") is not False:
    fail.append("config.yml: blank_issues_enabled must be false")

print("\n".join(fail) or "All issue form checks passed.")
sys.exit(1 if fail else 0)
