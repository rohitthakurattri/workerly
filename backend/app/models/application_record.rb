class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Models exposed in URLs get a UUID v7 public_id; bigint ids stay internal.
  def self.has_public_id
    before_validation { self.public_id ||= SecureRandom.uuid_v7 }
    define_method(:to_param) { public_id }
  end
end
