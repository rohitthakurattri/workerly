module Api
  module V1
    module Worker
      class ProfilesController < BaseController
        # GET /api/v1/worker/profile
        def show
          authorize current_profile
          render_profile
        end

        # PATCH /api/v1/worker/profile  (multipart when sending a photo)
        def update
          authorize current_profile
          attrs = params.require(:profile).permit(:bio, :experience_years, :photo)
          current_profile.update!(attrs)
          render_profile
        end

        # POST /api/v1/worker/profile/submit_for_review
        def submit
          authorize current_profile, :submit?
          Workers::SubmitForReview.call(profile: current_profile)
          render_profile
        end
      end
    end
  end
end
