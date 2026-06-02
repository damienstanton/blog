/**
 * Sync this blog's articles to AT Protocol records using the standard.site lexicons.
 *
 * Usage:
 *   pnpm atproto:sync           -- create/update real records on the PDS
 *   pnpm atproto:sync:dry       -- dry run: print what would happen, no network writes
 *
 * Required env vars (real run only):
 *   ATPROTO_IDENTIFIER  -- Bluesky handle, e.g. "you.bsky.social"
 *   ATPROTO_APP_PASSWORD -- Bluesky app password (not your main password)
 *
 * Optional env vars:
 *   ATPROTO_SERVICE     -- PDS base URL (default: https://bsky.social)
 *
 * Outputs:
 *   src/data/atproto-uris.json               -- slug → AT-URI mapping (commit this)
 *   public/.well-known/site.standard.publication -- publication AT-URI (commit this)
 */

import { AtpAgent } from '@atproto/api';
import { readdir, readFile, writeFile } from 'fs/promises';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');

const SITE_URL = process.env.ATPROTO_SITE_URL ?? 'https://damienstanton.com';
const SITE_NAME = 'Synthetic Horizons';
const SITE_DESCRIPTION =
  'Synthetic Horizons — personal notes on computer science and related fields.';

const DRY_RUN = process.argv.includes('--dry-run');

// ── Frontmatter parser (no external deps) ────────────────────────────────────

interface ArticleMeta {
  slug: string;
  title: string;
  description?: string;
  date?: string;
  atproto?: boolean;
}

function parseFrontmatter(raw: string): Record<string, string | boolean> {
  const match = raw.match(/^---\n([\s\S]*?)\n---/);
  if (!match) return {};
  const result: Record<string, string | boolean> = {};
  for (const line of match[1].split('\n')) {
    const colon = line.indexOf(':');
    if (colon === -1) continue;
    const key = line.slice(0, colon).trim();
    const val = line.slice(colon + 1).trim().replace(/^["']|["']$/g, '');
    result[key] = val === 'true' ? true : val === 'false' ? false : val;
  }
  return result;
}

async function loadArticles(): Promise<ArticleMeta[]> {
  const dir = join(ROOT, 'src/content/articles');
  const files = (await readdir(dir)).filter((f: string) => f.endsWith('.md'));
  const articles: ArticleMeta[] = [];
  for (const file of files) {
    const raw = await readFile(join(dir, file), 'utf8');
    const fm = parseFrontmatter(raw);
    if (fm.atproto === false) continue; // opt-out
    const slug = file.replace(/\.md$/, '');
    articles.push({
      slug,
      title: (fm.title as string) ?? slug,
      description: fm.description as string | undefined,
      date: fm.date as string | undefined,
    });
  }
  return articles;
}

// ── URI map ───────────────────────────────────────────────────────────────────

interface UriMap {
  publication: string;
  pubCreatedAt: string;
  documents: Record<string, string>;
}

const URI_MAP_PATH = join(ROOT, 'src/data/atproto-uris.json');
const WELL_KNOWN_PATH = join(ROOT, 'public/.well-known/site.standard.publication');

async function loadUriMap(): Promise<UriMap> {
  let raw: string;
  try {
    raw = await readFile(URI_MAP_PATH, 'utf8');
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === 'ENOENT') {
      return { publication: '', pubCreatedAt: '', documents: {} };
    }
    throw err;
  }
  return JSON.parse(raw) as UriMap;
}

async function saveUriMap(map: UriMap): Promise<void> {
  await writeFile(URI_MAP_PATH, JSON.stringify(map, null, 2) + '\n');
}

// AT-URI format: at://did/collection/rkey — rkey is always the last path segment
function rkeyFromUri(uri: string): string {
  const rkey = uri.split('/').at(-1);
  if (!rkey) throw new Error(`Malformed AT-URI: ${uri}`);
  return rkey;
}

function safeIso(dateStr: string | undefined): string {
  if (!dateStr) return new Date().toISOString();
  const d = new Date(dateStr);
  return isNaN(d.getTime()) ? new Date().toISOString() : d.toISOString();
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  const articles = await loadArticles();

  if (DRY_RUN) {
    console.log('Dry run — no records will be written to the PDS.\n');
    console.log(`Publication: "${SITE_NAME}" at ${SITE_URL}`);
    console.log(`Documents (${articles.length}):`);
    for (const a of articles) {
      console.log(`  [${a.slug}] "${a.title}" — ${a.date ?? '(no date)'}`);
    }
    if (!process.env.ATPROTO_IDENTIFIER) {
      console.error('\nWarning: ATPROTO_IDENTIFIER is not set — real run will fail.');
    }
    if (!process.env.ATPROTO_APP_PASSWORD) {
      console.error('Warning: ATPROTO_APP_PASSWORD is not set — real run will fail.');
    }
    return;
  }

  const identifier = process.env.ATPROTO_IDENTIFIER;
  const password = process.env.ATPROTO_APP_PASSWORD;
  if (!identifier || !password) {
    console.error('Error: ATPROTO_IDENTIFIER and ATPROTO_APP_PASSWORD must be set.');
    process.exit(1);
  }

  const service = process.env.ATPROTO_SERVICE ?? 'https://bsky.social';
  const agent = new AtpAgent({ service });
  await agent.login({ identifier, password });
  const did = agent.session?.did;
  if (!did) throw new Error('Login failed: no DID in session');
  console.log(`Authenticated as ${did}`);

  const map = await loadUriMap();

  // Upsert publication record — preserve original createdAt on updates
  const now = new Date().toISOString();
  const pubCreatedAt = map.pubCreatedAt || now;
  const pubRecord = {
    $type: 'site.standard.publication',
    url: SITE_URL,
    name: SITE_NAME,
    description: SITE_DESCRIPTION,
    createdAt: pubCreatedAt,
  };

  if (map.publication) {
    await agent.com.atproto.repo.putRecord({
      repo: did,
      collection: 'site.standard.publication',
      rkey: rkeyFromUri(map.publication),
      record: pubRecord,
    });
    console.log(`Updated publication: ${map.publication}`);
  } else {
    const res = await agent.com.atproto.repo.createRecord({
      repo: did,
      collection: 'site.standard.publication',
      record: pubRecord,
    });
    map.publication = res.data.uri;
    map.pubCreatedAt = pubCreatedAt;
    await saveUriMap(map);
    console.log(`Created publication: ${map.publication}`);
  }

  // Write domain verification file
  await writeFile(WELL_KNOWN_PATH, map.publication);
  console.log(`Wrote well-known: ${WELL_KNOWN_PATH}`);

  // Upsert document records
  for (const article of articles) {
    const docRecord = {
      $type: 'site.standard.document',
      publication: map.publication,
      title: article.title,
      ...(article.description ? { description: article.description } : {}),
      url: `${SITE_URL}/${article.slug}`,
      createdAt: safeIso(article.date),
    };

    if (map.documents[article.slug]) {
      await agent.com.atproto.repo.putRecord({
        repo: did,
        collection: 'site.standard.document',
        rkey: rkeyFromUri(map.documents[article.slug]),
        record: docRecord,
      });
      console.log(`Updated document [${article.slug}]: ${map.documents[article.slug]}`);
    } else {
      const res = await agent.com.atproto.repo.createRecord({
        repo: did,
        collection: 'site.standard.document',
        rkey: article.slug,
        record: docRecord,
      });
      map.documents[article.slug] = res.data.uri;
      await saveUriMap(map);
      console.log(`Created document [${article.slug}]: ${map.documents[article.slug]}`);
    }
  }

  await saveUriMap(map);
  console.log(`\nWrote URI map to ${URI_MAP_PATH}`);
}

main().catch((err) => {
  console.error('Error:', err instanceof Error ? err.message : err);
  process.exit(1);
});
