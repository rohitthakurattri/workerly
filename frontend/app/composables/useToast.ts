import { ref } from 'vue'

export type ToastTone = 'info' | 'success' | 'warning' | 'danger'
export interface Toast { id: number, tone: ToastTone, message: string }

const toasts = ref<Toast[]>([])
let nextId = 1

export function useToast() {
  function show(message: string, tone: ToastTone = 'info', timeoutMs = 4000) {
    const id = nextId++
    toasts.value.push({ id, tone, message })
    if (timeoutMs > 0) setTimeout(() => dismiss(id), timeoutMs)
    return id
  }
  function dismiss(id: number) {
    toasts.value = toasts.value.filter(t => t.id !== id)
  }
  return {
    toasts,
    show,
    dismiss,
    success: (m: string) => show(m, 'success'),
    error: (m: string) => show(m, 'danger', 6000),
  }
}
