<template>
  <div class="min-h-dvh">
    <SharedAppHeader title="Workerly">
      <SharedRoleSwitcher />
    </SharedAppHeader>
    <main class="mx-auto max-w-6xl px-4 py-6">
      <slot />
    </main>
  </div>
</template>
