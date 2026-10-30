<script setup lang="ts">
import { computed, ref } from 'vue'
import { useAuthStore } from '~/stores/auth'
import { STAFF_ROLES, type Role } from '~/targets'

const auth = useAuthStore()
const { target, switchRole, appUrlFor } = useAuth()
const toast = useToast()
const { t } = useI18n()
const busy = ref(false)

// Roles this session can switch to without logging in again.
const options = computed(() => (auth.user?.roles ?? []).filter(r =>
  target.scope === 'staff' ? STAFF_ROLES.includes(r) : !STAFF_ROLES.includes(r)))

async function choose(role: Role) {
  if (role === auth.activeRole) return
  // Customer and worker live on different apps; the shared refresh cookie carries the login across.
  if (target.scope === 'consumer') {
    const url = appUrlFor(role)
    if (url) await navigateTo(url, { external: true })
    return
  }
  busy.value = true
  try {
    await switchRole(role)
    toast.success(t('roles.switched', { role: t(`roles.${role}`) }))
  }
  catch (e) {
    toast.error((e as Error).message)
  }
  finally {
    busy.value = false
  }
}
</script>

<template>
  <div
    v-if="options.length > 1"
    class="flex items-center gap-1 rounded-full border border-border bg-surface p-1"
    role="group"
    :aria-label="t('roles.switch')"
  >
    <button
      v-for="role in options"
      :key="role"
      type="button"
      :disabled="busy"
      class="rounded-full px-3 py-1 text-sm"
      :class="role === auth.activeRole ? 'bg-brand-700 text-white' : 'text-ink-muted hover:bg-surface-muted'"
      :aria-pressed="role === auth.activeRole"
      @click="choose(role)"
    >
      {{ t(`roles.${role}`) }}
    </button>
  </div>
</template>
