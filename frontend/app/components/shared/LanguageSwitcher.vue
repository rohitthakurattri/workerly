<script setup lang="ts">
import { useAuthStore } from '~/stores/auth'

const { locale, locales, setLocale } = useI18n()
const auth = useAuthStore()
const { updateProfile } = useAuth()

async function change(event: Event) {
  const code = (event.target as HTMLSelectElement).value as 'en' | 'hi' | 'pa'
  await setLocale(code)
  // Remember it on the account too, so SMS and notifications use the same language.
  if (auth.isLoggedIn && auth.user?.locale !== code) await updateProfile({ locale: code }).catch(() => {})
}
</script>

<template>
  <label
    class="sr-only"
    for="lang"
  >Language</label>
  <select
    id="lang"
    :value="locale"
    class="h-9 rounded-[var(--radius-control)] border border-border bg-surface px-2 text-sm"
    @change="change"
  >
    <option
      v-for="l in locales"
      :key="l.code"
      :value="l.code"
    >
      {{ l.name }}
    </option>
  </select>
</template>
