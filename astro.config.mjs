import { defineConfig } from 'astro/config';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import { remarkMermaid } from './src/lib/remark-mermaid.ts';
import { readFile, access } from 'fs/promises';
import { join, extname } from 'path';
import { fileURLToPath } from 'url';

const root = fileURLToPath(new URL('.', import.meta.url));

const MIME = /** @type {Record<string, string>} */ ({
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
});

export default defineConfig({
  output: 'static',
  site: 'https://damienstanton.com',
  markdown: {
    remarkPlugins: [remarkMath, remarkMermaid],
    rehypePlugins: [rehypeKatex],
    shikiConfig: {
      themes: {
        light: 'rose-pine-dawn',
        dark: 'rose-pine-moon',
      },
    },
  },
  vite: {
    plugins: [
      {
        name: 'pagefind-dev-server',
        configureServer(server) {
          server.middlewares.use(async (req, res, next) => {
            if (!req.url?.startsWith('/pagefind/')) return next();
            const filePath = join(root, 'dist', req.url.split('?')[0]);
            try {
              await access(filePath);
              const content = await readFile(filePath);
              res.setHeader('Content-Type', MIME[extname(filePath)] ?? 'application/octet-stream');
              res.end(content);
            } catch {
              next();
            }
          });
        },
      },
    ],
  },
});
