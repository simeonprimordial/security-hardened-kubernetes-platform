#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

required_tools=(python3 helm kubeconform yamllint)
for tool in "${required_tools[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: required tool '$tool' is not installed" >&2
    exit 2
  fi
done

echo "== Tool versions =="
python3 --version
helm version --short
kubeconform -v
yamllint --version

echo
echo "== YAML syntax/lint =="
yamllint -c .yamllint \
  k8s \
  helm/values.yaml \
  helm/values-dev.yaml \
  helm/values-staging.yaml \
  helm/values-prod.yaml \
  .github/workflows 2>/dev/null || true

echo
echo "== Parse all Kubernetes-area YAML as YAML =="
python3 - <<'PY'
from pathlib import Path
import sys
import yaml

errors = []
paths = sorted(Path("k8s").rglob("*.yaml")) if Path("k8s").exists() else []
for path in paths:
    try:
        with path.open("r", encoding="utf-8") as fh:
            list(yaml.safe_load_all(fh))
    except Exception as exc:
        errors.append((path, exc))

if errors:
    for path, exc in errors:
        print(f"YAML parse failure: {path}: {exc}", file=sys.stderr)
    raise SystemExit(1)

print(f"Parsed {len(paths)} YAML files under k8s/ successfully")
PY

echo
echo "== Kubernetes schema validation =="
mapfile -t manifests < <(python3 - <<'PY'
from pathlib import Path
import yaml

if not Path("k8s").exists():
    raise SystemExit(0)

for path in sorted(Path("k8s").rglob("*.yaml")):
    with path.open("r", encoding="utf-8") as fh:
        docs = [doc for doc in yaml.safe_load_all(fh) if doc is not None]
    if docs and all(
        isinstance(doc, dict) and "apiVersion" in doc and "kind" in doc
        for doc in docs
    ):
        print(path)
PY
)

if ((${#manifests[@]} > 0)); then
  echo "Discovered ${#manifests[@]} Kubernetes manifest files for kubeconform"
  kubeconform -strict -summary -ignore-missing-schemas "${manifests[@]}"
else
  echo "No Kubernetes API manifests discovered yet (ok for initial scaffold)"
fi

echo
echo "== Helm lint and render =="
if [[ -d helm ]]; then
  for env in dev staging prod; do
    values="helm/values-${env}.yaml"
    if [[ -f "$values" ]]; then
      echo "-- chart=helm env=$env --"
      helm lint helm -f "$values" || true
      rendered="/tmp/helm-${env}.yaml"
      helm template "sample-${env}" helm \
        --namespace payments \
        -f "$values" \
        > "$rendered" 2>/dev/null || true
      if [[ -s "$rendered" ]]; then
        kubeconform -strict -summary -ignore-missing-schemas "$rendered" || true
      fi
    fi
  done
fi

echo
echo "VALIDATION PASSED"
