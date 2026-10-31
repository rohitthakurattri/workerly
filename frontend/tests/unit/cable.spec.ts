import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createCable } from '~/utils/cable'

class FakeSocket {
  static OPEN = 1
  static all: FakeSocket[] = []
  readyState = 0
  sent: unknown[] = []
  onmessage: ((e: { data: string }) => void) | null = null
  onclose: (() => void) | null = null
  constructor(public url: string) {
    FakeSocket.all.push(this)
  }

  send(data: string) {
    this.sent.push(JSON.parse(data))
  }

  close() {
    this.onclose?.()
  }

  server(msg: object) {
    this.readyState = 1
    this.onmessage?.({ data: JSON.stringify(msg) })
  }
}

const id = JSON.stringify({ channel: 'WorkerLeadsChannel' })
const flush = () => new Promise(r => setTimeout(r, 0))

describe('createCable', () => {
  beforeEach(() => {
    FakeSocket.all = []
  })
  afterEach(() => vi.useRealTimers())

  it('connects with a ticket, subscribes after welcome and delivers messages', async () => {
    const tickets = vi.fn().mockResolvedValue({ ticket: 't1', url: 'ws://api/cable' })
    const cable = createCable(tickets, FakeSocket as unknown as typeof WebSocket)
    const onMessage = vi.fn()
    const onConfirm = vi.fn()
    cable.subscribe('WorkerLeadsChannel', { onMessage, onConfirm })
    await flush()

    const ws = FakeSocket.all[0]!
    expect(ws.url).toBe('ws://api/cable?ticket=t1')
    ws.server({ type: 'welcome' })
    expect(ws.sent).toEqual([{ command: 'subscribe', identifier: id }])
    ws.server({ type: 'confirm_subscription', identifier: id })
    expect(onConfirm).toHaveBeenCalledOnce()
    ws.server({ identifier: id, message: { type: 'lead.new' } })
    expect(onMessage).toHaveBeenCalledWith({ type: 'lead.new' })
    ws.server({ type: 'ping', message: 123 })
    expect(onMessage).toHaveBeenCalledOnce()
    cable.close()
  })

  it('puts channel params in the identifier (RequestChannel id)', async () => {
    const cable = createCable(vi.fn().mockResolvedValue({ ticket: 't1', url: 'ws://api/cable' }), FakeSocket as unknown as typeof WebSocket)
    const onMessage = vi.fn()
    cable.subscribe('RequestChannel', { onMessage, params: { id: 'r1' } })
    await flush()
    const ws = FakeSocket.all.at(-1)!
    ws.server({ type: 'welcome' })
    const identifier = JSON.stringify({ channel: 'RequestChannel', id: 'r1' })
    expect(ws.sent).toEqual([{ command: 'subscribe', identifier }])
    ws.server({ identifier, message: { type: 'quote.new' } })
    expect(onMessage).toHaveBeenCalledWith({ type: 'quote.new' })
    cable.close()
  })

  it('reconnects with a fresh ticket and resubscribes (so callers can catch up)', async () => {
    vi.useFakeTimers()
    const tickets = vi.fn().mockResolvedValueOnce({ ticket: 't1', url: 'ws://a' }).mockResolvedValueOnce({ ticket: 't2', url: 'ws://a' })
    const cable = createCable(tickets, FakeSocket as unknown as typeof WebSocket)
    const onConfirm = vi.fn()
    cable.subscribe('WorkerLeadsChannel', { onMessage: vi.fn(), onConfirm })
    await vi.advanceTimersByTimeAsync(0)
    FakeSocket.all[0]!.server({ type: 'welcome' })
    FakeSocket.all[0]!.close()

    await vi.advanceTimersByTimeAsync(1000)
    const second = FakeSocket.all[1]!
    expect(second.url).toBe('ws://a?ticket=t2')
    second.server({ type: 'welcome' })
    second.server({ type: 'confirm_subscription', identifier: id })
    expect(second.sent).toEqual([{ command: 'subscribe', identifier: id }])
    expect(onConfirm).toHaveBeenCalledOnce()
    cable.close()
  })

  it('stops for good when the server says not to reconnect, or after close()', async () => {
    vi.useFakeTimers()
    const tickets = vi.fn().mockResolvedValue({ ticket: 't', url: 'ws://a' })
    const cable = createCable(tickets, FakeSocket as unknown as typeof WebSocket)
    await vi.advanceTimersByTimeAsync(0)
    FakeSocket.all[0]!.server({ type: 'disconnect', reconnect: false })
    FakeSocket.all[0]!.close()
    await vi.advanceTimersByTimeAsync(60_000)
    expect(FakeSocket.all).toHaveLength(1)
    cable.close()
  })

  it('backs off when it cannot get a ticket', async () => {
    vi.useFakeTimers()
    const tickets = vi.fn().mockRejectedValue(new Error('offline'))
    const cable = createCable(tickets, FakeSocket as unknown as typeof WebSocket)
    await vi.advanceTimersByTimeAsync(0)
    await vi.advanceTimersByTimeAsync(1000)
    await vi.advanceTimersByTimeAsync(2000)
    expect(tickets).toHaveBeenCalledTimes(3)
    expect(FakeSocket.all).toHaveLength(0)
    cable.close()
  })
})
