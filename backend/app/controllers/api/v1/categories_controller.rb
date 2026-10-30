module Api
  module V1
    class CategoriesController < BaseController
      skip_before_action :authenticate!

      # GET /api/v1/categories — active top-level categories with their children.
      def index
        roots = ServiceCategory.available.roots.includes(:children).order(:sort, :id)
        render_data(roots.map { |c| ServiceCategoryResource.new(c).to_h })
      end

      # GET /api/v1/categories/:slug
      def show
        render_data(ServiceCategoryResource.new(ServiceCategory.available.find_by!(slug: params[:slug])).to_h)
      end

      private

      # Public, identical for everyone: cacheable at the CDN, unlike other API responses.
      def no_store
        expires_in 5.minutes, public: true
      end
    end
  end
end
