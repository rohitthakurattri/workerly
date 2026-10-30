import withNuxt from './.nuxt/customer/eslint.config.mjs'

export default withNuxt({
  ignores: ['app/types/api.d.ts'],
})
