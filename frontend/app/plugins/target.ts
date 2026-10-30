// Tags <html> with the target so CSS tokens can re-tint per app.
export default defineNuxtPlugin(() => {
  const target = useRuntimeConfig().public.appTarget as string
  useHead({ htmlAttrs: { 'data-target': target } })
})
