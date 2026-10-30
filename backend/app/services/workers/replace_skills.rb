module Workers
  module ReplaceSkills
    module_function

    # skills: [{ category: "plumber", experience_years: 5 }, ...]
    def call(profile:, skills:)
      skills = Array(skills)
      raise ApplicationError.new(:too_many_skills, details: { max: WorkerProfile::MAX_SKILLS }) if skills.size > WorkerProfile::MAX_SKILLS

      slugs = skills.map { |s| s[:category].to_s }
      categories = ServiceCategory.available.where(slug: slugs).index_by(&:slug)
      unknown = slugs - categories.keys
      raise ApplicationError.new(:unknown_categories, details: { categories: unknown }) if unknown.any?

      WorkerProfile.transaction do
        profile.lock!
        keep_ids = categories.values.map(&:id)
        profile.worker_skills.where.not(service_category_id: keep_ids).destroy_all
        skills.each do |s|
          skill = profile.worker_skills.find_or_initialize_by(service_category: categories.fetch(s[:category].to_s))
          skill.update!(experience_years: s[:experience_years].presence)
        end
      end
      profile.worker_skills.reload
    end
  end
end
