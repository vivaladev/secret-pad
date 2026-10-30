#!/bin/bash
# Save secrets from a JSON array on stdin into the macOS Keychain.
# [{"name":"JIRA_TOKEN","value":"..."}]
# Values are not printed.

set -u

SERVICE="cursor-secret"
NAMES_FILE="${HOME}/.config/cursor-secrets/names"
SECURITY="/usr/bin/security"

if [[ -t 0 ]]; then
  echo "save-secrets: передай JSON в stdin" >&2
  exit 2
fi

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/save-secrets.XXXXXX")
chmod 700 "$tmpdir"
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/in.json"

/usr/bin/python3 - "$tmpdir" << 'PY'
import json
import os
import re
import sys
from pathlib import Path

tmpdir = Path(sys.argv[1])
try:
    items = json.loads((tmpdir / "in.json").read_text(encoding="utf-8"))
except Exception:
    sys.stderr.write("save-secrets: не разобрал JSON\n")
    sys.exit(2)

if not isinstance(items, list) or not items:
    sys.stderr.write("save-secrets: нечего сохранять\n")
    sys.exit(2)

name_re = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
seen = []
for index, item in enumerate(items):
    if not isinstance(item, dict):
        sys.stderr.write("save-secrets: плохая запись\n")
        sys.exit(2)
    name = str(item.get("name", "")).strip()
    value = item.get("value", "")
    if not isinstance(value, str):
        sys.stderr.write("save-secrets: значение должно быть строкой\n")
        sys.exit(2)
    if not name_re.match(name):
        sys.stderr.write("save-secrets: имя должно быть как JIRA_TOKEN: %s\n" % name)
        sys.exit(2)
    if name in seen:
        sys.stderr.write("save-secrets: имя повторяется: %s\n" % name)
        sys.exit(2)
    if value == "":
        sys.stderr.write("save-secrets: пустое значение: %s\n" % name)
        sys.exit(2)
    seen.append(name)
    path = tmpdir / ("v%03d" % index)
    path.write_bytes(value.encode("utf-8"))
    os.chmod(path, 0o600)

(tmpdir / "order").write_text("\n".join(seen) + "\n", encoding="utf-8")
PY

remember() {
  local name="$1"
  mkdir -p "$(dirname "$NAMES_FILE")"
  if [[ ! -f "$NAMES_FILE" ]]; then
    printf '%s\n' "# Одно имя переменной на строку. Значений здесь нет." > "$NAMES_FILE"
  fi
  if grep -Fxq -- "$name" "$NAMES_FILE"; then
    return 0
  fi
  if [[ -s "$NAMES_FILE" ]]; then
    local end
    end=$(tail -c 1 "$NAMES_FILE" | od -An -tu1 | tr -d ' ')
    if [[ "$end" != "10" ]]; then
      printf '\n' >> "$NAMES_FILE"
    fi
  fi
  printf '%s\n' "$name" >> "$NAMES_FILE"
}

idx=0
fail=0
while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  file=$(printf '%s/v%03d' "$tmpdir" "$idx")
  value=$(cat "$file"; printf x)
  value="${value%x}"
  if "$SECURITY" add-generic-password \
      -a "$name" \
      -s "$SERVICE" \
      -l "$name" \
      -T "$SECURITY" \
      -U \
      -w "$value"; then
    remember "$name"
  else
    echo "save-secrets: не записал ${name}" >&2
    fail=1
  fi
  idx=$((idx + 1))
done < "$tmpdir/order"

exit "$fail"
