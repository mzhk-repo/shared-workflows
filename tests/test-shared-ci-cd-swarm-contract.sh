#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$root/.github/workflows/shared-ci-cd-swarm.yml"

python3 - "$workflow" <<'PY'
import sys
import yaml

with open(sys.argv[1], encoding='utf-8') as handle:
    workflow = yaml.safe_load(handle)

inputs = workflow[True]['workflow_call']['inputs']
assert inputs['resolved_image_digest']['required'] is False
assert inputs['deployment_release_tag']['required'] is False
assert inputs['approval_context']['required'] is False
PY

grep -q 'updated_env=\$(mktemp /tmp/env\.decrypted\.XXXXXX)' "$workflow"
grep -q 'SMTP2GRAPH_IMAGE_DIGEST=" digest' "$workflow"
grep -q 'production deploy requires resolved_image_digest' "$workflow"
grep -q 'DEPLOYMENT_RELEASE_TAG="${DEPLOYMENT_RELEASE_TAG}"' "$workflow"
grep -q 'format: json' "$workflow"
grep -q 'output: trivy-\${{ inputs.release_tag }}\.json' "$workflow"
grep -q 'format: cyclonedx-json' "$workflow"
grep -q '! gh release view "${RELEASE_TAG}"' "$workflow"
grep -q 'name: Publish immutable release evidence' "$workflow"
if grep -q 'SOPS_AGE_KEY="$(cat /tmp/sops-age-key\.txt)"' "$workflow"; then
    printf 'ERROR: remote orchestration unexpectedly receives the SOPS age private key.\n' >&2
    exit 1
fi

printf 'PASS: shared Swarm contract keeps digest optional and enforces production deploy context.\n'
