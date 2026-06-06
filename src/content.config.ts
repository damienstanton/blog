import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const SECTIONS = ['Personal', 'Independent Study', 'MSCS'] as const;

const articles = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/articles' }),
  schema: z.object({
    title: z.string(),
    section: z.enum(SECTIONS),
    date: z.date().optional(),
    description: z.string().optional(),
    atproto: z.boolean().optional(),
  }),
});

export const collections = { articles };
