<script setup lang="ts">
import { useAuthStore } from '~/stores/auth'

defineProps<{ title: string }>()
const auth = useAuthStore()
const { logout } = useAuth()
const { t } = useI18n()
</script>

<template>
  <header class="sticky top-0 z-30 border-b border-border bg-surface/95 backdrop-blur">
    <div class="mx-auto flex h-14 max-w-5xl items-center justify-between gap-3 px-4">
      <NuxtLink
        to="/"
        class="text-lg font-bold text-brand-700"
      >
        {{ title }}
      </NuxtLink>
      <div class="flex items-center gap-2">
        <SharedLanguageSwitcher />
        <slot />
        <UiButton
          v-if="auth.isLoggedIn"
          variant="ghost"
          size="sm"
          @click="logout"
        >
          {{ t('auth.logout') }}
        </UiButton>
      </div>
    </div>
  </header>
</template>
