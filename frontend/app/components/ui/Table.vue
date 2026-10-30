<script setup lang="ts" generic="Row extends Record<string, unknown>">
interface Column { key: string, label: string, align?: 'left' | 'right' }

defineProps<{ columns: Column[], rows: Row[], rowKey: keyof Row, caption?: string }>()
</script>

<template>
  <div class="overflow-x-auto rounded-[var(--radius-card)] border border-border bg-surface">
    <table class="w-full text-sm">
      <caption
        v-if="caption"
        class="sr-only"
      >
        {{ caption }}
      </caption>
      <thead class="bg-surface-muted text-left text-ink-muted">
        <tr>
          <th
            v-for="c in columns"
            :key="c.key"
            scope="col"
            class="px-4 py-2.5 font-medium"
            :class="c.align === 'right' && 'text-right'"
          >
            {{ c.label }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="row in rows"
          :key="String(row[rowKey])"
          class="border-t border-border"
        >
          <td
            v-for="c in columns"
            :key="c.key"
            class="px-4 py-3"
            :class="c.align === 'right' && 'text-right tabular-nums'"
          >
            <slot
              :name="`cell-${c.key}`"
              :row="row"
            >
              {{ row[c.key] }}
            </slot>
          </td>
        </tr>
      </tbody>
    </table>
    <slot
      v-if="!rows.length"
      name="empty"
    />
  </div>
</template>
