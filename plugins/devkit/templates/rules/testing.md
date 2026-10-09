---
paths:
  - "**/*.{test,spec}.{ts,tsx,js,jsx}"
  - "{{E2E_DIR}}/**/*"
---
<!-- TEMPLATE: adjust to the real test framework. -->
# Testing

- Framework: {{TEST_FRAMEWORK}}; shared helpers in `{{TEST_UTILS}}`
- Test names include the acceptance criterion ID when written for a task, e.g. `AC2: shows an error for an invalid email`
- Test behavior through the public API or through the UI as a user would; avoid mocking internals
- Mock the network with {{NETWORK_MOCK_LIB}}; unit tests never call real APIs
- No snapshots of large components; assert specific content and interactions
