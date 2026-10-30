import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import { nextTick } from 'vue'
import Button from '~/components/ui/Button.vue'
import Input from '~/components/ui/Input.vue'
import Badge from '~/components/ui/Badge.vue'
import Toaster from '~/components/ui/Toaster.vue'
import { useToast } from '~/composables/useToast'

describe('UiButton', () => {
  it('is disabled and busy while loading', () => {
    const w = mount(Button, { props: { loading: true }, slots: { default: 'Save' } })
    const btn = w.get('button')
    expect(btn.attributes('disabled')).toBeDefined()
    expect(btn.attributes('aria-busy')).toBe('true')
  })

  it('defaults to type=button so it never submits forms by accident', () => {
    expect(mount(Button).get('button').attributes('type')).toBe('button')
  })
})

describe('UiInput', () => {
  it('links the label and error message for screen readers', () => {
    const w = mount(Input, { props: { label: 'Mobile', error: 'Invalid', id: 'phone' } })
    expect(w.get('label').attributes('for')).toBe('phone')
    const input = w.get('input')
    expect(input.attributes('aria-invalid')).toBe('true')
    expect(input.attributes('aria-describedby')).toBe('phone-error')
    expect(w.get('#phone-error').text()).toBe('Invalid')
  })

  it('supports v-model and passes attributes to the input', async () => {
    const w = mount(Input, { props: { 'label': 'Code', 'modelValue': '', 'inputmode': 'numeric', 'onUpdate:modelValue': (v: string) => w.setProps({ modelValue: v }) } })
    await w.get('input').setValue('123456')
    expect(w.props('modelValue')).toBe('123456')
    expect(w.get('input').attributes('inputmode')).toBe('numeric')
  })
})

describe('UiBadge', () => {
  it('applies the tone token classes', () => {
    expect(mount(Badge, { props: { tone: 'danger' } }).classes()).toContain('text-danger')
  })
})

describe('UiToaster', () => {
  it('shows and dismisses toasts', async () => {
    const w = mount(Toaster)
    const toast = useToast()
    toast.show('Saved', 'success', 0)
    toast.error('Failed')
    await nextTick()
    expect(w.text()).toContain('Saved')
    expect(w.find('[role="alert"]').text()).toContain('Failed')

    await w.findAll('button')[0]!.trigger('click')
    expect(w.text()).not.toContain('Saved')
  })
})
