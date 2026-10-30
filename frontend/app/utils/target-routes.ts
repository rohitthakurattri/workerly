import type { AppTarget } from '../targets'

interface PageLike { path: string, name?: string, children?: PageLike[] }

const ALL: AppTarget[] = ['customer', 'worker', 'admin']

/**
 * pages/<target>/** become the app's routes with the prefix removed; other targets'
 * pages are dropped, so their code never ships in this build. Shared pages stay.
 */
export function routesForTarget<T extends PageLike>(pages: T[], target: AppTarget): T[] {
  const others = ALL.filter(x => x !== target)
  const owns = (path: string, t: string) => path === `/${t}` || path.startsWith(`/${t}/`)

  return pages
    .filter(p => !others.some(o => owns(p.path, o)))
    .map((page) => {
      if (!owns(page.path, target)) return page
      return {
        ...page,
        path: page.path.slice(target.length + 1) || '/',
        name: page.name ? page.name.replace(new RegExp(`^${target}-?`), '') || 'index' : page.name,
      }
    })
}
