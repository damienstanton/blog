import { getCollection, type CollectionEntry } from 'astro:content';

export const SECTIONS = ['Personal', 'Independent Study', 'MSCS'] as const;
export type Section = (typeof SECTIONS)[number];
export const PER_PAGE = 10;

const SECTION_ORDER: Record<Section, number> = {
  'Personal': 0,
  'Independent Study': 1,
  MSCS: 2,
};

export function readingTime(body: string): number {
  return Math.ceil(body.split(/\s+/).filter(Boolean).length / 200);
}

export async function getSortedArticles(): Promise<CollectionEntry<'articles'>[]> {
  const articles = await getCollection('articles');
  return articles.sort((a, b) => {
    const sectionDiff = SECTION_ORDER[a.data.section] - SECTION_ORDER[b.data.section];
    if (sectionDiff !== 0) return sectionDiff;
    const dateA = a.data.date?.getTime() ?? 0;
    const dateB = b.data.date?.getTime() ?? 0;
    if (dateA !== dateB) return dateA - dateB;
    return a.data.title.localeCompare(b.data.title);
  });
}

export interface PageResult {
  articles: CollectionEntry<'articles'>[];
  currentPage: number;
  totalPages: number;
  hasNext: boolean;
  hasPrev: boolean;
}

export function paginateArticles(
  articles: CollectionEntry<'articles'>[],
  page: number,
): PageResult {
  const start = (page - 1) * PER_PAGE;
  const end = start + PER_PAGE;
  return {
    articles: articles.slice(start, end),
    currentPage: page,
    totalPages: Math.ceil(articles.length / PER_PAGE),
    hasNext: end < articles.length,
    hasPrev: page > 1,
  };
}
