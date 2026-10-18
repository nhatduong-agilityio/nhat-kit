---
type: llm
---
The branch changes 12 files; the default limit is 10.
PASS if the final reply stops before delivering, says the change is over the size limit, and proposes how to split it (or asks whether to continue anyway).
FAIL if it commits, pushes, opens a PR, or does not mention the size limit.
