<script setup lang="ts">
definePageMeta({ public: true, layout: false })

const { target } = useAuth()
const route = useRoute()
const { t } = useI18n()
useHead({ title: `${t('auth.title')} · ${target.name}` })

function done() {
  const redirect = typeof route.query.redirect === 'string' && route.query.redirect.startsWith('/') && !route.query.redirect.startsWith('//')
    ? route.query.redirect
    : '/'
  return navigateTo(redirect)
}
</script>

<template>
  <div class="flex min-h-dvh items-center justify-center px-4 py-10">
    <div class="w-full max-w-sm">
      <div class="mb-6 text-center">
        <p class="text-2xl font-bold text-brand-700">
          {{ target.name }}
        </p>
        <h1 class="mt-2 text-lg text-ink-muted">
          {{ t(`auth.subtitle.${target.scope === 'staff' ? 'admin' : $config.public.appTarget}`) }}
        </h1>
      </div>
      <UiCard>
        <ClientOnly>
          <SharedOtpLoginForm @done="done" />
          <template #fallback>
            <UiSkeleton :lines="3" />
          </template>
        </ClientOnly>
      </UiCard>
      <div class="mt-4 flex justify-center">
        <SharedLanguageSwitcher />
      </div>
    </div>
  </div>
</template>
