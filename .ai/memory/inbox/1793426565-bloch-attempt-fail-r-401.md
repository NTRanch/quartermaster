---
origin_lane: restricted
content_label: nsfw
evidence: default: restricted-origin without positive SFW evidence
---
# Attempt failed — R-401 Performance budget holds on target hardware

last_verified: 2026-10-31
applies_to: 0.1.0
disposition: 
scope: repo_task
subject: R-401

error: test $(wc -c < web/index.html) -le 524288 && test $(stat -c%s docs/previews/level-3-quartermaster.mp4) -le 4194304: exit code 1
note: 
