import { ref } from 'vue'
import type { Category, City } from '~/types/models'

const categories = ref<Category[]>([])
const cities = ref<City[]>([])

/** Public catalog, fetched once per app session. */
export function useCatalog() {
  const api = useApi()

  async function load() {
    if (!categories.value.length) categories.value = (await api<{ data: Category[] }>('/categories')).data
    if (!cities.value.length) cities.value = (await api<{ data: City[] }>('/cities')).data
  }

  /** Categories a request can be filed under (no sub-categories), like ServiceCategory.requestable. */
  function leaves(list: Category[] = categories.value): Category[] {
    return list.flatMap(c => (c.children.length ? leaves(c.children) : [c]))
  }

  return { categories, cities, load, leaves }
}
