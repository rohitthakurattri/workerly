<script setup lang="ts">
const { canViewWorkers, canViewAudit, canViewRequests } = useStaff()
const { t } = useI18n()
</script>

<template>
  <div class="min-h-dvh">
    <SharedAppHeader title="Workerly Admin">
      <SharedRoleSwitcher />
    </SharedAppHeader>
    <nav
      class="border-b border-border bg-surface"
      :aria-label="t('admin.nav')"
    >
      <div class="mx-auto flex max-w-6xl gap-1 overflow-x-auto px-4">
        <NuxtLink
          to="/"
          class="admin-tab"
        >
          {{ t('admin.dashboard') }}
        </NuxtLink>
        <NuxtLink
          v-if="canViewWorkers"
          to="/workers"
          class="admin-tab"
        >
          {{ t('admin.workers') }}
        </NuxtLink>
        <NuxtLink
          v-if="canViewRequests"
          to="/requests"
          class="admin-tab"
        >
          {{ t('admin.requests') }}
        </NuxtLink>
        <NuxtLink
          v-if="canViewAudit"
          to="/audit-logs"
          class="admin-tab"
        >
          {{ t('admin.auditLog') }}
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
.admin-tab { @apply whitespace-nowrap border-b-2 border-transparent px-3 py-3 text-sm font-medium text-ink-muted hover:text-ink; }
.admin-tab.router-link-exact-active, .admin-tab.router-link-active:not([href="/"]) { @apply border-brand-700 text-ink; }
</style>
