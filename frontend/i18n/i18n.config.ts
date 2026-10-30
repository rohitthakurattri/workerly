// Staff-only screens are English-only for now; missing hi/pa keys fall back to English.
export default defineI18nConfig(() => ({
  fallbackLocale: 'en',
  missingWarn: false,
  fallbackWarn: false,
}))
