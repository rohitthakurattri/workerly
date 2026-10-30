<template>
  <div class="min-h-dvh">
    <SharedAppHeader title="Workerly Pro">
      <SharedRoleSwitcher />
    </SharedAppHeader>
    <main class="mx-auto max-w-5xl px-4 py-6">
      <slot />
    </main>
  </div>
</template>
