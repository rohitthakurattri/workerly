class ServiceCategory < ApplicationRecord
  include I18nName

  belongs_to :parent, class_name: "ServiceCategory", optional: true
  has_many :children, -> { order(:sort, :id) }, class_name: "ServiceCategory", foreign_key: :parent_id,
           inverse_of: :parent, dependent: :restrict_with_error
  has_many :worker_skills, dependent: :restrict_with_error

  i18n_attribute :name_i18n, :description_i18n
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validate { errors.add(:name_i18n, "needs an English name") if name_i18n.to_h["en"].blank? }
  validate { errors.add(:parent, "cannot be itself") if parent_id.present? && parent_id == id }

  scope :kept, -> { where(deleted_at: nil) }
  scope :available, -> { kept.where(active: true) }
  scope :roots, -> { where(parent_id: nil) }
end
