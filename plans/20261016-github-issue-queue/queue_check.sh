#!/usr/bin/env bash
# End-to-end check of the devkit issue-queue gh calls on the private scratch repo.
set -u
R=nhatduong-agilityio/devkit-forms-scratch
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

# 1. Labels: create only the missing ones.
existing="$(gh label list -R "$R" --limit 200 --json name --jq '.[].name')"
while IFS='|' read -r name color desc; do
  if ! grep -qx "$name" <<< "$existing"; then
    gh label create "$name" -R "$R" --color "$color" --description "$desc" >/dev/null && echo "created $name"
  fi
done <<'EOF'
ai|5319e7|In the AI work queue
severity:critical|b60205|Impact: critical
severity:high|d93f0b|Impact: high
severity:medium|fbca04|Impact: medium
severity:low|c2e0c6|Impact: low
area:web|0e8a16|Area: web
in-progress|1d76db|Claimed by one machine
EOF
gh label list -R "$R" --limit 200 --json name --jq '.[].name' | grep -qx 'severity:critical' && ok "labels exist" || bad "labels"

# 2. Three issues with different severities, filed low → critical → high.
tag="qc-$(date +%s)"
for sev in low critical high; do
  gh issue create -R "$R" --title "[$tag] $sev: queue check" --body "Queue check ($sev)." \
    --label ai --label bug --label "severity:$sev" --label area:web >/dev/null
  sleep 1
done

# 3. next: open ai issues without in-progress, by severity rank then oldest.
next_q='map(select(.title|startswith("['"$tag"']")))
  | map(select([.labels[].name] | index("in-progress") | not))
  | map(. + {rank: ([.labels[].name | select(startswith("severity:"))][0]
      | {"severity:critical":0,"severity:high":1,"severity:medium":2,"severity:low":3}[.] // 4)})
  | sort_by(.rank, .createdAt) | map("\(.number) \(.title)") | .[]'
for try in 1 2 3 4 5 6 7 8 9 10; do   # gh issue list lags a few seconds behind new issues
  order="$(gh issue list -R "$R" --label ai --state open --limit 100 --json number,title,labels,createdAt --jq "$next_q")"
  [ "$(echo "$order" | grep -c .)" -ge 3 ] && break
  sleep 2
done
echo "listed after $try tries"
echo "$order"
[ "$(echo "$order" | sed -E 's/.*\] ([a-z]+):.*/\1/' | tr '\n' ' ')" = "critical high low " ] && ok "next order critical → high → low" || bad "next order"
top="$(echo "$order" | head -1 | cut -d' ' -f1)"

# 4. Claim the top issue, then re-read.
host="$(hostname -s)"
gh issue edit "$top" -R "$R" --add-label in-progress >/dev/null
gh issue comment "$top" -R "$R" --body "🔒 devkit claim · host: $host · task: GH-$top · $(date -u +%Y-%m-%dT%H:%M:%SZ)" >/dev/null
claims="$(gh issue view "$top" -R "$R" --json comments --jq '[.comments[].body | select(startswith("🔒 devkit claim"))] | length')"
labels="$(gh issue view "$top" -R "$R" --json labels --jq '[.labels[].name] | join(",")')"
[ "$claims" = 1 ] && [[ "$labels" == *in-progress* ]] && ok "claim visible on re-read ($labels)" || bad "claim ($claims, $labels)"
after_claim="$(gh issue list -R "$R" --label ai --state open --limit 100 --json number,title,labels,createdAt --jq "$next_q" | head -1 | cut -d' ' -f1)"
[ "$after_claim" != "$top" ] && ok "claimed issue skipped by next (now #$after_claim)" || bad "claimed issue still first"

# 5. Release: remove label, comment, stays open and back in the queue.
gh issue edit "$top" -R "$R" --remove-label in-progress >/dev/null
gh issue comment "$top" -R "$R" --body "🔓 devkit release · host: $host · reason: queue check · done so far: nothing" >/dev/null
state="$(gh issue view "$top" -R "$R" --json state,labels --jq '.state + " " + ([.labels[].name] | join(","))')"
[[ "$state" == OPEN* ]] && [[ "$state" != *in-progress* ]] && [[ "$state" == *ai* ]] && ok "released: $state" || bad "release ($state)"
back="$(gh issue list -R "$R" --label ai --state open --limit 100 --json number,title,labels,createdAt --jq "$next_q" | head -1 | cut -d' ' -f1)"
[ "$back" = "$top" ] && ok "released issue is first in next again" || bad "not back in queue"

echo "tag=$tag top=#$top"
exit "$fail"
