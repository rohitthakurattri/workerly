module Workers
  # What a profile still needs before it can be submitted for review.
  module Requirements
    module_function

    def missing(profile)
      missing = []
      missing << "name" if profile.user.name.blank?
      missing << "photo" unless profile.photo.attached?
      missing << "experience_years" if profile.experience_years.nil?
      missing << "skills" if profile.worker_skills.empty?
      missing << "service_area" if profile.service_areas.empty?
      live = profile.documents.live.pluck(:kind)
      WorkerDocument::REQUIRED_KINDS.each { |kind| missing << "document_#{kind}" unless live.include?(kind) }
      missing
    end
  end
end
