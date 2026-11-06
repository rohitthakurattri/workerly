/** Map tiles for Leaflet, from runtime config (NUXT_PUBLIC_MAP_*). */
export type MapProvider = 'osm' | 'maptiler' | 'custom'

export interface MapTileSettings {
  mapProvider?: string
  maptilerKey?: string
  maptilerStyle?: string
  mapTileUrl?: string
  mapAttribution?: string
}

export interface MapTiles {
  provider: MapProvider
  url: string
  attribution: string
  options: { maxZoom: number, minZoom?: number, crossOrigin?: boolean }
  /** Set when the settings ask for something that can't be served (e.g. MapTiler with no key). */
  problem?: string
}

const OSM: MapTiles = {
  provider: 'osm',
  url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  attribution: '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a> contributors',
  options: { maxZoom: 19 },
}

// MapTiler requires both credits on every map (and its logo on the free plan).
const MAPTILER_ATTRIBUTION = '<a href="https://www.maptiler.com/copyright/" target="_blank" rel="noopener">&copy; MapTiler</a> '
  + '<a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">&copy; OpenStreetMap contributors</a>'

/**
 * - osm (default): OpenStreetMap's own servers, for development only (their usage policy).
 * - maptiler: NUXT_PUBLIC_MAPTILER_KEY (restrict it to the app domains in MapTiler's dashboard;
 *   browser keys are public) and NUXT_PUBLIC_MAPTILER_STYLE (default streets-v4). 256 px raster
 *   tiles, @2x on high-density screens.
 * - custom: NUXT_PUBLIC_MAP_TILE_URL and NUXT_PUBLIC_MAP_ATTRIBUTION as given.
 */
export function resolveMapTiles(s: MapTileSettings): MapTiles {
  const provider = (s.mapProvider || 'osm') as MapProvider
  if (provider === 'maptiler') {
    const key = (s.maptilerKey || '').trim()
    if (!key) return { ...OSM, problem: 'NUXT_PUBLIC_MAP_PROVIDER=maptiler needs NUXT_PUBLIC_MAPTILER_KEY; showing OpenStreetMap tiles instead.' }
    const style = (s.maptilerStyle || 'streets-v4').replace(/[^\w-]/g, '')
    return {
      provider,
      url: `https://api.maptiler.com/maps/${style}/256/{z}/{x}/{y}{r}.png?key=${encodeURIComponent(key)}`,
      attribution: MAPTILER_ATTRIBUTION,
      options: { maxZoom: 20, minZoom: 1, crossOrigin: true },
    }
  }
  if (provider === 'custom') {
    if (!s.mapTileUrl) return { ...OSM, problem: 'NUXT_PUBLIC_MAP_PROVIDER=custom needs NUXT_PUBLIC_MAP_TILE_URL; showing OpenStreetMap tiles instead.' }
    return { provider, url: s.mapTileUrl, attribution: s.mapAttribution || '', options: { maxZoom: 19 } }
  }
  return OSM
}
