<script setup lang="ts">
import { useAuthStore } from '~/stores/auth'

defineProps<{ title: string }>()
const auth = useAuthStore()
const { logout } = useAuth()
const { t } = useI18n()
</script>

<template>
  <header class="sticky top-0 z-30 print:hidden border-b border-border bg-surface/95 backdrop-blur">
    <div class="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-x-3 gap-y-2 px-4 py-2.5">
      <NuxtLink
        to="/"
        class="whitespace-nowrap text-lg font-bold text-brand-700"
      >
        {{ title }}
      </NuxtLink>
      <div class="flex items-center gap-2">
        <SharedLanguageSwitcher />
        <UiButton
          v-if="auth.isLoggedIn"
          variant="ghost"
          size="sm"
          @click="logout"
        >
          {{ t('auth.logout') }}
        </UiButton>
      </div>
      <!-- Role switch drops to its own row on phones so nothing overflows. -->
      <div
        v-if="$slots.default"
        class="flex w-full justify-end sm:order-none sm:w-auto"
      >
        <slot />
      </div>
    </div>
  </header>
</template>
