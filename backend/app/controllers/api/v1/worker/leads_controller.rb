module Api
  module V1
    module Worker
      class LeadsController < BaseController
        # GET /api/v1/worker/leads
        # Gate is live now; matching fills this list in Phase 4.
        def index
          authorize :lead, :index?
          render_data([], meta: { next_cursor: nil })
        end

        # GET /api/v1/worker/leads/:id
        def show
          authorize :lead, :show?
          raise ActiveRecord::RecordNotFound
        end
      end
    end
  end
end
