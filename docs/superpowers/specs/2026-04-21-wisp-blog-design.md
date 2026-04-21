# wisp-blog Design Spec

**Date:** 2026-04-21
**Status:** Approved

## Overview

A simple, beautiful static personal notes site built with Astro 4.x and TypeScript. Content is imported from the [damienstanton/notes](https://github.com/damienstanton/notes) mdBook repository (available at `.claude/context/notes/`). The site is self-contained: after the one-time import, content lives in `src/content/articles/` and the notes submodule is not a runtime dependency.

## Goals

- Single-column reading experience, top navigation
- Scholarly serif aesthetic with warm light and dark palettes
- Light/dark mode: system preference detected, manual toggle with `localStorage` persistence, no flash on load
- Reading time per article, computed at build time
- Easy to extend: adding a new article = dropping a `.md` file into `src/content/articles/`
- Total `dist/` build under 300 MB; no single file ≥ 100 MB

## Stack

| Concern | Choice |
|---------|--------|
| Framework | Astro 4.x |
| Language | TypeScript (strict) |
| Package manager | pnpm |
| Markdown | Astro built-in (`@astrojs/markdown-remark`) |
| Content schema | Astro Content Collections + Zod |
| Styling | Plain CSS (CSS custom properties for theming) |
| Fonts (body/headings) | Georgia, serif stack |
| Fonts (monospace) | Maple Mono via fontsource CDN |
| UI framework | None (pure Astro components) |
| Deployment | Static (`output: 'static'`) |

## Layout

Single-column layout. Top nav contains the site title on the left and section links + theme toggle on the right. All content is centered with a max-width of ~680px. Section links in the nav are anchor links (`/#about`, `/#independent-study`, `/#mscs`) that jump to the corresponding section heading on the index page — no client-side routing or JS filtering needed.

Two page types:

1. **Index (`/`)** — lists all articles grouped by section (About, Independent Study, MSCS), each showing title, section label, reading time, and a one-sentence excerpt.
2. **Article (`/[slug]`)** — full article content, same nav, reading time shown below the title.

## Visual Design

### Typography

- **Body / article text:** Georgia, serif. Line-height 1.8, comfortable for long-form reading.
- **Nav, labels, metadata:** System sans-serif (`system-ui, -apple-system, sans-serif`). Uppercase, tracked for section labels.
- **Code (inline + blocks):** `Maple Mono`, monospace. Loaded via fontsource CDN:
  ```html
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@fontsource/maple-mono/index.css">
  ```

### Color Tokens

| Token | Light | Dark |
|-------|-------|------|
| `--bg` | `#fafaf8` | `#1c1814` |
| `--bg-secondary` | `#f5f0e8` | `#231f1b` |
| `--border` | `#e8e4dc` | `#2e2824` |
| `--text` | `#1a1a1a` | `#e8e0d5` |
| `--text-muted` | `#9a8f82` | `#6b6058` |
| `--text-body` | `#5a4f46` | `#a09080` |
| `--accent` | `#c8b89a` | `#6b5a45` |

### Theming

- CSS custom properties on `:root` (light defaults) and `[data-theme="dark"]`.
- System detection via `prefers-color-scheme: dark` media query.
- Manual override: `◐` toggle in the top nav writes `"light"` or `"dark"` to `localStorage`.
- An inline `<script>` in `<head>` (before any CSS paint) reads `localStorage` and sets `data-theme` on `<html>` — eliminates flash of unstyled content on reload.

## Content Structure

### Frontmatter Schema

```yaml
---
title: string           # required
section: string         # "About" | "Independent Study" | "MSCS"
date: date              # optional, used for ordering within section
description: string     # optional, shown as excerpt in ArticleCard
---
```

### Derived Fields (computed at build time in `config.ts`)

- `readingTime: number` — `Math.ceil(wordCount / 200)` minutes. Displayed as `N min read`.
- `slug` — derived from filename (Astro default).

### One-Time Content Import

Source: `.claude/context/notes/notebook/src/`

Files to import (per `SUMMARY.md`):

| Source file | Target | Section | Notes |
|-------------|--------|---------|-------|
| `about.md` | `about.md` | About | Add frontmatter |
| `me.md` | `me.md` | About | Add frontmatter |
| `harper_ctt.md` | `harper_ctt.md` | Independent Study | Add frontmatter |
| `bauer_algeff.md` | `bauer_algeff.md` | Independent Study | Add frontmatter |
| `mscs.md` | `mscs.md` | MSCS | Add frontmatter |
| `5414.md` | `5414.md` | MSCS | Add frontmatter |
| `5065.md` | `5065.md` | MSCS | Add frontmatter |
| `open_source.md` | `open_source.md` | Independent Study | Add frontmatter |
| `code.md` | `code.md` | About | Add frontmatter |

`SUMMARY.md`, `placeholder.md`, and Rust source files (`app.rs`, `lib.rs`, `bin/`, `oss/`, `mscs/`) are not imported.

## File Structure

```
src/
  content/
    articles/          ← imported + frontmatter-annotated markdown
    config.ts          ← Zod schema with readingTime derived field
  layouts/
    Base.astro         ← <html>, theme inline script, global CSS link, Maple Mono CDN link
    Article.astro      ← wraps Base, adds article-specific layout
  components/
    Nav.astro          ← site title + section links + ThemeToggle
    ThemeToggle.astro  ← ◐/◑ button; reads/writes localStorage
    ArticleList.astro  ← groups articles by section, renders ArticleCard list
    ArticleCard.astro  ← title, section label, reading time, excerpt
  pages/
    index.astro        ← imports ArticleList
    [slug].astro       ← renders article via Article layout
  styles/
    global.css         ← CSS custom properties, reset, typography, theme
astro.config.mjs
package.json           ← pnpm, Astro, TypeScript
tsconfig.json
```

## Build Output Constraints

- `output: 'static'` in `astro.config.mjs`
- No images in source content (text-only articles)
- No bundled font files (Maple Mono via CDN)
- No UI framework JS (React/Vue/Svelte)
- Expected `dist/` size: < 5 MB (HTML + CSS only)
- Constraint ceiling: total < 300 MB, no single file ≥ 100 MB (trivially met)

## Extending the Site

To add a new article:

1. Create `src/content/articles/my-new-article.md`
2. Add frontmatter: `title`, `section`, `date` (optional), `description` (optional)
3. Run `pnpm build` — reading time is computed automatically, article appears in the index grouped by its section

No code changes required.

## Out of Scope

- Search
- Pagination
- Comments
- RSS feed
- Analytics
- KaTeX / Mermaid rendering (present in source mdBook but not in scope for v1)
- Syncing from the notes submodule (content is imported once; updates are manual)
