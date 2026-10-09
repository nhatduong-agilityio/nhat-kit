---
paths:
  - "{{FRONTEND_DIR}}/**/*.{ts,tsx,js,jsx,vue,svelte}"
---
<!-- TEMPLATE: example for React + TS. Keep only rules that differ from the project's defaults; fix the paths. -->
# Frontend

- Components: function components + hooks; one main component per file, file named after the component
- Server state through {{DATA_LIB}}; never fetch inside `useEffect`
- Every screen handles loading, empty, and error states
- User-facing text goes through {{I18N_LIB}}; no hard-coded strings
- Reuse components from `{{UI_KIT_DIR}}` before creating new ones; colors and spacing come from design tokens
- Accessibility: interactive elements have labels and are keyboard-navigable
