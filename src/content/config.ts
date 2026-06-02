import { defineCollection, z } from 'astro:content';

const SECTIONS = ['Personal', 'Independent Study', 'MSCS'] as const;

const articles = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    section: z.enum(SECTIONS),
    date: z.date().optional(),
    description: z.string().optional(),
    atproto: z.boolean().optional(),
  }),
});

export const collections = { articles };
