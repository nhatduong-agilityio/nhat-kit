<!-- TEMPLATE: fill every {{...}}, delete lines that don't apply and every TEMPLATE comment. Target: under 120 lines. -->
# {{PROJECT_NAME}}

{{ONE_SENTENCE_PRODUCT_DESCRIPTION}}. Business context, scope, and open questions: `docs/PROJECT_BRIEF.md`. Architecture: `docs/architecture.md`.

# Commands
<!-- TEMPLATE: only commands that ran successfully -->
- Install: `{{INSTALL_CMD}}`
- Dev server: `{{DEV_CMD}}`
- Quick check after each batch of changes: `{{TYPECHECK_CMD}} && {{LINT_CMD}}`
- Test one file (prefer this over the full suite): `{{TEST_ONE_CMD}} <path>`
- Full test suite: `{{TEST_ALL_CMD}}`
- Build: `{{BUILD_CMD}}`

# Stack & layout
- {{FRAMEWORK}} · {{LANGUAGE}} · {{STATE_DATA_LIB}} · {{STYLING}} · tests with {{TEST_FRAMEWORK}}
- {{DIR_1}}: {{ROLE}}
- {{DIR_2}}: {{ROLE}}
<!-- TEMPLATE: only list folders whose names don't explain their role -->

# Conventions that differ from defaults
<!-- TEMPLATE: only what Claude can't infer. Examples: -->
- Package manager: {{PM}}, never {{OTHER_PM}}
- Import via the `{{ALIAS}}` alias
- Never edit `{{GENERATED_DIR}}` by hand — run `{{CODEGEN_CMD}}`
- {{KEY_BUSINESS_RULE}}

# Language
- All artifacts in English: code, comments, commits, plans, specs, PRs, docs

# Workflow
- BA tasks: run `/devkit:task <ticket>`; specs live in `docs/tasks/<ID>-<slug>/SPEC.md`
- Other changes: `/devkit:plan` → `/devkit:cook` → `/devkit:ship`; plans live in `plans/`
- Branches: `{{BRANCH_PATTERN}}`; Conventional Commits referencing the task ID
- Before reporting done: every AC/goal has evidence (tests, command + output, screenshot)
- Never push without approval
- When compacting: keep the path of the SPEC/plan in progress, the list of modified files, and the test commands in use

# Gotchas
<!-- TEMPLATE: environment quirks, required env vars, services that must run first. Delete this section if empty. -->
- {{GOTCHA}}
