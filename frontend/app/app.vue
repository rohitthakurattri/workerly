<script setup lang="ts">
import { computed } from 'vue'
import type { AppTarget } from '~/targets'

const target = useRuntimeConfig().public.appTarget as AppTarget
const route = useRoute()
// Each app uses the layout named after it, unless a page opts out (e.g. login).
const layout = computed(() => (route.meta.layout === false ? false : target))
</script>

<template>
  <NuxtLayout :name="layout">
    <NuxtPage />
  </NuxtLayout>
  <UiToaster />
</template>
