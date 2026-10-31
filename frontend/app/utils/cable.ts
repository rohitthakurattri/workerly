/**
 * Minimal Action Cable client. Each (re)connect fetches a fresh one-time ticket, because the
 * server refuses reused tickets, which the official client can't do. `onConfirm` runs after every
 * (re)subscription so callers can refetch anything missed while offline.
 */
export interface CableTicket { ticket: string, url: string }
interface Subscription { onMessage: (msg: unknown) => void, onConfirm?: () => void }

export function createCable(getTicket: () => Promise<CableTicket>, WS: typeof WebSocket = WebSocket) {
  const subs = new Map<string, Subscription>()
  let ws: WebSocket | null = null
  let closed = false
  let retry = 0
  let timer: ReturnType<typeof setTimeout> | undefined

  const send = (command: string, identifier: string) => {
    if (ws?.readyState === WS.OPEN) ws.send(JSON.stringify({ command, identifier }))
  }

  function schedule() {
    if (closed) return
    timer = setTimeout(connect, Math.min(30_000, 1000 * 2 ** retry++))
  }

  async function connect() {
    if (closed) return
    let t: CableTicket
    try {
      t = await getTicket()
    }
    catch {
      return schedule()
    }
    if (closed) return
    const socket = new WS(`${t.url}?ticket=${encodeURIComponent(t.ticket)}`, ['actioncable-v1-json'])
    ws = socket
    socket.onmessage = (e) => {
      const data = JSON.parse(String(e.data)) as { type?: string, identifier?: string, message?: unknown, reconnect?: boolean }
      if (data.type === 'welcome') {
        retry = 0
        for (const id of subs.keys()) send('subscribe', id)
      }
      else if (data.type === 'confirm_subscription' && data.identifier) {
        subs.get(data.identifier)?.onConfirm?.()
      }
      else if (data.type === 'disconnect' && data.reconnect === false) {
        closed = true
      }
      else if (data.identifier && data.message !== undefined) {
        subs.get(data.identifier)?.onMessage(data.message)
      }
    }
    socket.onclose = () => {
      if (ws === socket) ws = null
      schedule()
    }
  }

  function subscribe(channel: string, sub: Subscription) {
    const identifier = JSON.stringify({ channel })
    subs.set(identifier, sub)
    send('subscribe', identifier)
    return () => {
      subs.delete(identifier)
      send('unsubscribe', identifier)
    }
  }

  function close() {
    closed = true
    clearTimeout(timer)
    ws?.close()
  }

  void connect()
  return { subscribe, close }
}
