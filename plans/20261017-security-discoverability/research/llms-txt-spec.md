# llms.txt specification research

Date: 2026-10-17. Question: current llms.txt spec, placement, examples, pitfalls, Claude Code built-ins.

## Conclusion
llms.txt (llmstxt.org) is a markdown file at a site root or subpath. Only the H1 is required. A blockquote summary, free prose, and H2 sections of link lists follow it. `llms-full.txt` is not in the spec. It is a vendor convention: one file holding the full docs text. Claude Code has no built-in that generates llms.txt. It only publishes its own (`code.claude.com/docs/llms.txt`), so devkit could add a skill for this without overlap.

## Details needed to implement
Order of elements (per llmstxt.org and the AnswerDotAI/llms-txt repo):
1. Optional BOM.
2. `# Name` (H1). The only required element.
3. `> Summary` blockquote with the key facts needed to understand the rest.
4. Zero or more prose or list blocks with no headings (notes, caveats, how to use the links).
5. Zero or more `## Section` blocks, each a markdown list of links.

Link line format: `- [Title](https://url): optional notes`. The link is required. The colon and notes are optional, but the spec recommends brief, informative descriptions.

`## Optional` is a reserved section name by convention. Agents may skip it when they need shorter context.

Example (written by me):
```
# Acme SDK
> Python SDK for the Acme API. Supports sync and async clients; Python 3.10+.

Auth uses API keys via the ACME_API_KEY env var.

## Docs
- [Quickstart](https://acme.dev/docs/quickstart.md): install and first request
- [API reference](https://acme.dev/docs/api.md): all client methods

## Optional
- [Changelog](https://acme.dev/changelog.md): release history
```

Placement:
- (a) Websites and docs sites: serve at `/llms.txt` (like robots.txt). Subpaths such as `/docs/llms.txt` are allowed. A file covers URLs beneath it, and the most specific file wins. Recommended extras: serve a markdown twin of each page (append `.md`, or `.html.md`), and optionally advertise it with `<link rel="alternate" type="text/markdown">` or an HTTP `Link:` header.
- (b) Repos and libraries: the spec has no repo-specific rule. Practice is to commit `llms.txt` at the repo root and publish it with the docs site (GitHub Pages or the docs host root). Link to absolute URLs (raw GitHub or the docs site) so the file works when fetched outside the repo. Relative links break for remote agents. (The repo-root advice is my inference, not stated in the spec.)

llms-full.txt: not defined by llmstxt.org (the spec repo does not mention it). In practice, docs platforms generate it as the entire documentation concatenated into one markdown file, next to llms.txt. Anthropic's platform docs index points to `https://platform.claude.com/llms-full.txt`. llms.txt is the small index. llms-full.txt is the big, load-everything variant.

## Real-world examples (opened)
- Claude Code docs: `https://code.claude.com/docs/llms.txt`. H1 plus a blockquote, then H2/H4 nested groups, each entry `- [Title](url.md): one-line description`. Links point to `.md` pages.
- Anthropic platform docs: `https://platform.claude.com/docs/llms.txt` (`docs.anthropic.com/llms.txt` 301-redirects there). It has a language list, many sections, and a closing pointer to llms-full.txt.
- Stripe: `https://docs.stripe.com/llms.txt`. Opens with agent guidance (use the CLI, check the latest package versions), then a long `## Docs` list with `.md` links. About 96 KB, which shows how large these files can get.
- The spec site itself: `https://llmstxt.org/llms.txt` (small, as intended).

## Pitfalls and limits
- Stale or broken links: generate the file from the source tree or sitemap, and add a link check in CI.
- Too long: the spec wants the file to fit in context, with detail behind links. Stripe-size files defeat that. Move secondary items to `## Optional`, and leave bulk content to llms-full.txt.
- Secrets and internal URLs: the file is public. Never list private, staging, or internal hostnames, tokens, or unreleased pages. Review it like a public README.
- Links to HTML pages instead of markdown cost agents more tokens. Prefer `.md` twins.
- Missing or vague descriptions make it hard for agents to pick links. Test by asking an LLM questions using only the file.
- It is a proposal and not a ratified standard. No guarantee that crawlers or LLM providers read it.

## Claude Code built-ins
- `code.claude.com/docs/llms.txt` has no page about generating llms.txt (checked).
- Repo grep: llms mentions in this repo are only upstream-watch notes on ClaudeKit's `docs.claudekit.cc/llms.txt`. There is no existing generator in devkit.
- Conclusion: a devkit skill would not duplicate a built-in. I did not exhaustively check `/commands` or the changelog beyond the docs index.

## Sources
- https://llmstxt.org/
- https://llmstxt.org/llms.txt
- https://github.com/AnswerDotAI/llms-txt
- https://code.claude.com/docs/llms.txt
- https://platform.claude.com/docs/llms.txt
- https://docs.stripe.com/llms.txt
