#!/usr/bin/env bash
# Usage: ./deploy.sh <org-alias>
# Deploys BidPilot, assigns the permission set, loads demo data and runs the Apex tests.
set -euo pipefail
ORG="${1:-bidpilot}"

echo "==> Deploying BidPilot metadata to $ORG"
sf project deploy start --source-dir force-app --target-org "$ORG" --wait 30

echo "==> Assigning BidPilot_User permission set"
sf org assign permset --name BidPilot_User --target-org "$ORG" || echo "   (already assigned)"

echo "==> Loading demo data (resources, past projects, sample SOW BID)"
sf apex run --file scripts/apex/seed.apex --target-org "$ORG"

echo "==> Running Apex tests"
sf apex run test --class-names BidPilotTests --code-coverage --result-format human --wait 15 --target-org "$ORG" || true

echo ""
echo "Done. Next: configure the agent (README section 3) and add the BidPilot Dashboard to the Bid page (README section 2)."
sf org open --target-org "$ORG" --path "/lightning/o/Bid__c/list" || true
