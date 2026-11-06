# What Workerly keeps from a job: percent_bps of the labour charges plus fixed_minor, taken from
# the worker's share (the customer always pays the quoted price). Most specific rule wins.
class CommissionRule < ApplicationRecord
  belongs_to :city, optional: true
  belongs_to :service_category, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  validates :percent_bps, numericality: { only_integer: true, in: 0..5000 }
  validates :fixed_minor, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :effective_from, presence: true

  # The rule in force for a city and category at a moment: city+category, then category, then
  # city, then the global rule; the latest effective_from among the most specific level.
  def self.for(city:, category:, at: Time.current)
    candidates = where(effective_from: ..at)
                 .where(city_id: [ city&.id, nil ], service_category_id: [ category&.id, nil ])
                 .order(effective_from: :desc).to_a
    candidates.min_by do |r|
      specificity = (r.city_id && r.service_category_id) ? 0 : (r.service_category_id ? 1 : (r.city_id ? 2 : 3))
      [ specificity, -r.effective_from.to_f ]
    end
  end
end
