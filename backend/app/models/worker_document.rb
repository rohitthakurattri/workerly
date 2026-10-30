class WorkerDocument < ApplicationRecord
  include AttachmentRules

  # Which doc_types may be uploaded for each kind. A driving licence, voter ID or
  # passport also proves address. Full Aadhaar copies are not accepted, only masked ones.
  DOC_TYPES = {
    "identity" => %w[aadhaar_masked pan voter_id driving_licence passport],
    "address" => %w[aadhaar_masked voter_id driving_licence passport utility_bill rent_agreement],
    "trade" => %w[trade_certificate other]
  }.freeze
  REQUIRED_KINDS = %w[identity address].freeze
  STATUSES = %w[pending approved rejected superseded].freeze

  has_public_id
  belongs_to :worker_profile
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_one_attached :file

  attachment_rules :file, types: AttachmentRules::DOCUMENT_TYPES, max_size: 10.megabytes, required: true
  validates :kind, inclusion: { in: DOC_TYPES.keys }
  validates :doc_type, inclusion: { in: ->(d) { DOC_TYPES.fetch(d.kind, []) } }
  validates :status, inclusion: { in: STATUSES }
  validates :number_last4, format: { with: /\A[A-Za-z0-9]{4}\z/ }, allow_blank: true

  scope :live, -> { where(status: %w[pending approved]) }

  def number_last4=(value)
    super(value.to_s.gsub(/[^A-Za-z0-9]/, "").last(4).upcase.presence)
  end
end
