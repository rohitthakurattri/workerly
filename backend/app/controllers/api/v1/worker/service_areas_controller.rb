module Api
  module V1
    module Worker
      class ServiceAreasController < BaseController
        before_action { authorize current_profile, :update? }

        # GET /api/v1/worker/service_areas
        def index
          render_data(current_profile.service_areas.includes(:city).map { |a| WorkerServiceAreaResource.new(a).to_h })
        end

        # POST /api/v1/worker/service_areas { city, lat, lng, radius_m, label }
        def create
          if current_profile.service_areas.count >= WorkerProfile::MAX_SERVICE_AREAS
            raise ApplicationError.new(:too_many_service_areas, details: { max: WorkerProfile::MAX_SERVICE_AREAS })
          end

          area = current_profile.service_areas.create!(area_attributes)
          render_data(WorkerServiceAreaResource.new(area).to_h, status: :created)
        end

        # PATCH /api/v1/worker/service_areas/:id
        def update
          area = current_profile.service_areas.find_by!(public_id: params[:id])
          area.update!(area_attributes(partial: true))
          render_data(WorkerServiceAreaResource.new(area).to_h)
        end

        # DELETE /api/v1/worker/service_areas/:id — an approved worker must keep at least one.
        def destroy
          area = current_profile.service_areas.find_by!(public_id: params[:id])
          if current_profile.approved? && current_profile.service_areas.count == 1
            raise ApplicationError.new(:last_service_area, status: :conflict)
          end

          area.destroy!
          head :no_content
        end

        private

        def area_attributes(partial: false)
          p = params.permit(:city, :lat, :lng, :radius_m, :label)
          attrs = { radius_m: p[:radius_m], label: p[:label] }
          attrs[:city] = City.find_by!(slug: p[:city]) if p[:city].present? || !partial
          if p[:lat].present? || p[:lng].present? || !partial
            raise ApplicationError.new(:location_required, details: { field_errors: { center: [ "lat and lng are required" ] } }) if p[:lat].blank? || p[:lng].blank?

            attrs[:center] = GeoPoint.point(lat: p[:lat], lng: p[:lng])
          end
          partial ? attrs.compact : attrs
        end
      end
    end
  end
end
