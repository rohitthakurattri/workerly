<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import type * as Leaflet from 'leaflet'
import 'leaflet/dist/leaflet.css'
import type { LatLng } from '~/types/models'
import { resolveMapTiles } from '~/utils/map-tiles'

/**
 * Tap or drag the pin to choose a point. `v-model` stays null until the user picks one
 * (or GPS answers), so callers can tell "chosen" from "still at the fallback centre".
 */
const props = withDefaults(defineProps<{
  fallback?: LatLng | null
  radiusM?: number | null
  autoLocate?: boolean
  label: string
}>(), { fallback: null, radiusM: null, autoLocate: false })
const point = defineModel<LatLng | null>({ default: null })
const emit = defineEmits<{ located: [LatLng] }>()

const config = useRuntimeConfig()
const { t } = useI18n()
const el = ref<HTMLElement | null>(null)
const map = shallowRef<Leaflet.Map | null>(null)
const locating = ref(false)
const gpsError = ref<string | null>(null)
let L: typeof Leaflet | null = null
let marker: Leaflet.Marker | null = null
let circle: Leaflet.Circle | null = null

const DEFAULT_CENTER: LatLng = { lat: 30.7046, lng: 76.7179 } // Mohali
const round = (n: number) => Number(n.toFixed(6))
const current = () => point.value ?? props.fallback ?? DEFAULT_CENTER

function place(p: LatLng, pan = false) {
  marker?.setLatLng([p.lat, p.lng])
  circle?.setLatLng([p.lat, p.lng])
  if (pan) map.value?.setView([p.lat, p.lng], Math.max(map.value.getZoom(), 16))
}

// Returns the chosen point: with a parent v-model, `point.value` only updates after the parent re-renders.
function choose(p: { lat: number, lng: number }): LatLng {
  const chosen = { lat: round(p.lat), lng: round(p.lng) }
  point.value = chosen
  return chosen
}

function drawCircle() {
  if (!L || !map.value) return
  circle?.remove()
  // SVG attributes can't read CSS variables, so resolve the app's brand colour here.
  const color = el.value ? getComputedStyle(el.value).getPropertyValue('--color-brand-600').trim() || '#0d9488' : '#0d9488'
  circle = props.radiusM
    ? L.circle([current().lat, current().lng], { radius: props.radiusM, color, weight: 2, fillOpacity: 0.08 }).addTo(map.value)
    : null
  if (circle) map.value.fitBounds(circle.getBounds(), { padding: [12, 12] })
}

function locate() {
  gpsError.value = null
  if (!('geolocation' in navigator)) {
    gpsError.value = t('map.gpsUnavailable')
    return
  }
  locating.value = true
  navigator.geolocation.getCurrentPosition(
    (pos) => {
      locating.value = false
      const chosen = choose({ lat: pos.coords.latitude, lng: pos.coords.longitude })
      place(chosen, true)
      emit('located', chosen)
    },
    () => {
      locating.value = false
      gpsError.value = t('map.gpsDenied')
    },
    { enableHighAccuracy: true, timeout: 10_000, maximumAge: 60_000 },
  )
}

onMounted(async () => {
  L = await import('leaflet')
  if (!el.value) return
  const start = current()
  map.value = L.map(el.value).setView([start.lat, start.lng], 15)
  const tiles = resolveMapTiles(config.public)
  if (tiles.problem) console.warn(`[map] ${tiles.problem}`)
  L.tileLayer(tiles.url, { ...tiles.options, attribution: tiles.attribution }).addTo(map.value)
  const icon = L.divIcon({ className: 'wk-pin', html: '<span></span>', iconSize: [28, 36], iconAnchor: [14, 34] })
  marker = L.marker([start.lat, start.lng], { draggable: true, icon, title: props.label, alt: props.label }).addTo(map.value)
  marker.on('dragend', () => choose(marker!.getLatLng()))
  map.value.on('click', (e: Leaflet.LeafletMouseEvent) => place(choose(e.latlng)))
  drawCircle()
  if (props.autoLocate && !point.value) locate()
})

onBeforeUnmount(() => map.value?.remove())

watch(() => props.radiusM, drawCircle)
// A new fallback (e.g. another city) recentres the map while nothing has been picked yet.
watch(() => props.fallback, (f) => {
  if (f && !point.value) place(f, true)
})
watch(point, (p) => {
  if (!p) place(current(), true)
})
</script>

<template>
  <div class="flex flex-col gap-2">
    <div
      ref="el"
      class="h-64 w-full overflow-hidden rounded-[var(--radius-card)] border border-border bg-surface-muted sm:h-80"
      role="application"
      :aria-label="label"
      data-testid="map"
    />
    <div class="flex flex-wrap items-center justify-between gap-2">
      <p class="text-sm text-ink-muted">
        {{ point ? t('map.pinSet') : t('map.tapToPin') }}
      </p>
      <UiButton
        variant="secondary"
        size="sm"
        :loading="locating"
        @click="locate"
      >
        📍 {{ t('map.useMyLocation') }}
      </UiButton>
    </div>
    <p
      v-if="gpsError"
      class="text-sm text-danger"
      role="alert"
    >
      {{ gpsError }}
    </p>
  </div>
</template>

<style>
/* Leaflet's default marker images don't survive bundling; a CSS pin needs no assets. */
.wk-pin span {
  position: absolute; left: 2px; top: 0; width: 24px; height: 24px;
  border-radius: 50% 50% 50% 0; transform: rotate(-45deg);
  background: var(--color-brand-700); border: 3px solid #fff; box-shadow: 0 1px 4px rgb(0 0 0 / 0.4);
}
</style>
