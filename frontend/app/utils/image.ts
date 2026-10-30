/** Largest size that fits inside max x max, keeping the aspect ratio. Never upscales. */
export function fitWithin(width: number, height: number, max: number): { width: number, height: number } {
  const scale = Math.min(1, max / Math.max(width, height))
  return { width: Math.round(width * scale), height: Math.round(height * scale) }
}

/**
 * Shrinks a phone photo before upload (a 4 MB camera JPEG becomes ~300 KB), which is most of
 * the wait on mobile data. Re-encoding also drops EXIF; the server strips it again regardless.
 * Falls back to the original file when the browser can't decode it (e.g. HEIC on Android).
 */
export async function compressImage(file: File, max = 1600, quality = 0.82): Promise<File> {
  if (typeof createImageBitmap !== 'function') return file
  let bitmap: ImageBitmap
  try {
    bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' })
  }
  catch {
    return file
  }
  const size = fitWithin(bitmap.width, bitmap.height, max)
  const canvas = document.createElement('canvas')
  canvas.width = size.width
  canvas.height = size.height
  canvas.getContext('2d')?.drawImage(bitmap, 0, 0, size.width, size.height)
  bitmap.close()
  const blob = await new Promise<Blob | null>(resolve => canvas.toBlob(resolve, 'image/jpeg', quality))
  if (!blob || blob.size >= file.size) return file
  return new File([blob], file.name.replace(/\.\w+$/, '') + '.jpg', { type: 'image/jpeg' })
}
