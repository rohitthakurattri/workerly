class RequestAttachment < ApplicationRecord
  include AttachmentRules

  KINDS = %w[image audio video].freeze
  TRANSCRIPT_STATUSES = %w[pending succeeded failed skipped].freeze
  # What browsers' MediaRecorder produces (Chrome/Firefox WebM or Ogg Opus, Safari MP4/AAC), as
  # Marcel sniffs it from the bytes: a WebM or MP4 container may be reported as video/*.
  VOICE_TYPES = %w[audio/webm video/webm audio/ogg audio/mp4 audio/x-m4a video/mp4 audio/mpeg audio/wav audio/x-wav].freeze
  VOICE_MAX_SIZE = 3.megabytes
  VOICE_MAX_MS = 120_000

  has_public_id
  belongs_to :service_request
  belongs_to :transcription_analysis, class_name: "AiAnalysis", optional: true
  has_one_attached :file

  validates :kind, inclusion: { in: KINDS }
  validates :transcript_status, inclusion: { in: TRANSCRIPT_STATUSES }, allow_nil: true
  validate :file_rules

  scope :voice_notes, -> { where(kind: "audio") }

  def image? = kind == "image"
  def audio? = kind == "audio"

  private

  # Images are re-encoded to JPEG on upload (Requests::AddPhoto), which also strips EXIF/GPS.
  def file_rules
    unless file.attached?
      errors.add(:file, :blank)
      return
    end
    types, max = audio? ? [ VOICE_TYPES, VOICE_MAX_SIZE ] : [ %w[image/jpeg], 10.megabytes ]
    errors.add(:file, "must be one of: #{types.map { |t| t.split('/').last }.uniq.join(', ')}") unless types.include?(file.blob.content_type)
    errors.add(:file, "must be smaller than #{max / 1.megabyte} MB") if file.blob.byte_size > max
  end
end
