module Api
  module V1
    module Worker
      class SkillsController < BaseController
        # PUT /api/v1/worker/skills { skills: [{ category: "plumber", experience_years: 4 }] }
        # Replaces the whole set.
        def update
          authorize current_profile, :update?
          skills = params.require(:skills).map { |s| s.permit(:category, :experience_years).to_h.symbolize_keys }
          Workers::ReplaceSkills.call(profile: current_profile, skills:)
          render_profile
        end
      end
    end
  end
end
