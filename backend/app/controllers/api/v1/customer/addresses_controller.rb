module Api
  module V1
    module Customer
      class AddressesController < BaseController
        # GET /api/v1/customer/addresses — default first, then newest.
        def index
          authorize Address
          addresses = policy_scope(Address).includes(:city).order(is_default: :desc, created_at: :desc)
          render_data(addresses.map { |a| AddressResource.new(a).to_h })
        end

        # POST /api/v1/customer/addresses { label, line1, line2, landmark, locality, pincode, lat, lng, is_default }
        # The city comes from the pin; a pin outside every launched city is refused.
        def create
          authorize Address
          if policy_scope(Address).count >= Address::MAX_PER_USER
            raise ApplicationError.new(:too_many_addresses, details: { max: Address::MAX_PER_USER })
          end

          address = current_user.addresses.new(address_attributes)
          save_with_default!(address, make_default: address.is_default || policy_scope(Address).none?)
          render_data(AddressResource.new(address).to_h, status: :created)
        end

        # PATCH /api/v1/customer/addresses/:id — submitted requests keep their own copy, so editing is safe.
        def update
          address = policy_scope(Address).find_by!(public_id: params[:id])
          authorize address
          address.assign_attributes(address_attributes(partial: true))
          save_with_default!(address, make_default: address.is_default_changed? && address.is_default)
          render_data(AddressResource.new(address).to_h)
        end

        # DELETE /api/v1/customer/addresses/:id — soft delete; drafts using it ask for another address.
        def destroy
          address = policy_scope(Address).find_by!(public_id: params[:id])
          authorize address
          address.soft_delete!
          head :no_content
        end

        private

        def address_attributes(partial: false)
          p = params.permit(:label, :line1, :line2, :landmark, :locality, :pincode, :lat, :lng, :is_default)
          attrs = p.slice(:label, :line1, :line2, :landmark, :locality, :pincode).to_h.transform_values { |v| v.to_s.strip.presence }
          attrs = attrs.compact if partial
          attrs[:is_default] = ActiveModel::Type::Boolean.new.cast(p[:is_default]) if p.key?(:is_default)
          if p[:lat].present? || p[:lng].present? || !partial
            raise ApplicationError.new(:location_required, details: { field_errors: { location: [ "lat and lng are required" ] } }) if p[:lat].blank? || p[:lng].blank?

            attrs[:location] = GeoPoint.point(lat: p[:lat], lng: p[:lng])
          end
          attrs
        end

        # One default per user (also a partial unique index): clear the old one in the same transaction.
        def save_with_default!(address, make_default:)
          Address.transaction do
            if make_default
              policy_scope(Address).where(is_default: true).where.not(id: address.id).update_all(is_default: false, updated_at: Time.current)
              address.is_default = true
            end
            address.save!
          end
        end
      end
    end
  end
end
