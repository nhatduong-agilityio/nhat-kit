---
paths:
  - "{{API_DIR}}/**/*"
---
<!-- TEMPLATE: for API/route handler/service folders that call APIs. Delete if not applicable. -->
# API

- Validate input at the boundary with {{VALIDATION_LIB}}; never trust data from clients or external APIs
- Return errors in the standard format from `{{ERROR_MODULE}}`
- Check authorization on every endpoint that writes data
- Never log tokens, passwords, or personal data
- Call external APIs through the client in `{{API_CLIENT_DIR}}`, with timeouts and network error handling
