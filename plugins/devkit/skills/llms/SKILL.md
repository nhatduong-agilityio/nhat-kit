---
name: llms
description: Generate or refresh the project's llms.txt — a short public index of its docs and API for LLM agents. Use when publishing a library, API, or docs site.
argument-hint: "[output path]"
disable-model-invocation: true
allowed-tools: Bash(git ls-files *) Bash(git remote *) Bash(git symbolic-ref *) Bash(git branch *)
---

# llms.txt

Output path: `$ARGUMENTS` (default `./llms.txt`). Work in one pass, with no agent. Write in English.

1. **Collect sources.** Use tracked files only (`git ls-files`): the README, `docs/**/*.md`, OpenAPI/Swagger specs, route definitions, and the entry points named in the package manifest. Read just enough of each to write a one-line note.
2. **Resolve the base URL.** Every link must be absolute.
   - Prefer a docs site from the manifest (`homepage` or a docs setting).
   - Otherwise, for a GitHub `origin` (`git remote get-url origin`), normalize it to `<owner>/<repo>`: accept SSH (`git@github.com:owner/repo.git`) and HTTPS (`https://github.com/owner/repo.git`) forms and strip a trailing `.git`. Then use `https://raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>`. The branch is `git symbolic-ref --short refs/remotes/origin/HEAD` without the `origin/` prefix; if that fails, `git branch --show-current`.
   - Otherwise ask the user.
3. **Build the file** in this order: one `# Name`, a `> summary` of the key facts, optional short prose, `## <Section>` lists with lines `- [Title](url): note`, and last `## Optional` for secondary items. Keep it to about 40 links; detail stays behind the links.
4. **Filter to public content.** The file is published, so leave out:
   - `.env*` files;
   - URLs with `localhost`, private IP ranges, or `staging`, `internal`, or `dev.` hosts;
   - pages with `draft: true` in the front matter, or under a `drafts/` directory.

   Name what you excluded in the reply, never in the file.
5. **Write the file.** If it already exists, show a diff and **wait for confirmation** before overwriting.
6. **Reply** with the path and the link count. Remind the user to publish the file at the site root (or the docs subpath) and to re-run this skill after doc changes.
