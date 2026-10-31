import { durationParts } from '~/utils/quotes'

/** "1 h 30 min" in the current language. */
export function useDuration() {
  const { t } = useI18n()
  return (minutes?: number | null) => {
    if (!minutes) return ''
    const p = durationParts(minutes)
    return [p.days && t('compare.duration.d', { n: p.days }), p.hours && t('compare.duration.h', { n: p.hours }),
      p.minutes && t('compare.duration.m', { n: p.minutes })].filter(Boolean).join(' ')
  }
}
