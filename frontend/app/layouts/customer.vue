<script setup lang="ts">
import { useAuthStore } from '~/stores/auth'

const auth = useAuthStore()
const { t } = useI18n()
</script>

<template>
  <div class="min-h-dvh">
    <SharedAppHeader title="Workerly">
      <SharedRoleSwitcher />
    </SharedAppHeader>
    <nav
      v-if="auth.isLoggedIn"
      class="border-b border-border bg-surface"
      :aria-label="t('customer.nav')"
    >
      <div class="mx-auto flex max-w-6xl gap-1 overflow-x-auto px-4">
        <NuxtLink
          to="/"
          class="customer-tab"
        >
          {{ t('customer.myRequests') }}
        </NuxtLink>
        <NuxtLink
          to="/addresses"
          class="customer-tab"
        >
          {{ t('addresses.title') }}
        </NuxtLink>
      </div>
    </nav>
    <main class="mx-auto max-w-6xl px-4 py-6">
      <slot />
    </main>
  </div>
</template>

<style scoped>
@reference "~/assets/css/main.css";
.customer-tab { @apply whitespace-nowrap border-b-2 border-transparent px-3 py-3 text-sm font-medium text-ink-muted hover:text-ink; }
.customer-tab.router-link-exact-active, .customer-tab.router-link-active:not([href="/"]) { @apply border-brand-700 text-ink; }
</style>
