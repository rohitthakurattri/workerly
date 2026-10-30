import { afterEach, describe, expect, it, vi } from 'vitest'
import { compressImage, fitWithin } from '~/utils/image'

describe('fitWithin', () => {
  it('scales the long side down to the limit, keeping the aspect ratio', () => {
    expect(fitWithin(4000, 3000, 1600)).toEqual({ width: 1600, height: 1200 })
    expect(fitWithin(3000, 4000, 1600)).toEqual({ width: 1200, height: 1600 })
  })

  it('never upscales small photos', () => {
    expect(fitWithin(800, 600, 1600)).toEqual({ width: 800, height: 600 })
  })
})

describe('compressImage', () => {
  afterEach(() => vi.unstubAllGlobals())
  const file = new File([new Uint8Array(10)], 'IMG_1.HEIC', { type: 'image/heic' })

  it('keeps the original when the browser cannot decode it (e.g. HEIC)', async () => {
    vi.stubGlobal('createImageBitmap', vi.fn().mockRejectedValue(new Error('unsupported')))
    expect(await compressImage(file)).toBe(file)
  })

  it('keeps the original when the browser has no createImageBitmap', async () => {
    vi.stubGlobal('createImageBitmap', undefined)
    expect(await compressImage(file)).toBe(file)
  })
})
