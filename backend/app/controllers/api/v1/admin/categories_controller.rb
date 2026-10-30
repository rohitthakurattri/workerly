module Api
  module V1
    module Admin
      class CategoriesController < BaseController
        # GET /api/v1/admin/categories — includes inactive ones.
        def index
          authorize [ :admin, ServiceCategory ]
          rows = ServiceCategory.kept.includes(:parent).order(:parent_id, :sort, :id)
          render_data(rows.map { |c| serialize(c) })
        end

        # POST /api/v1/admin/categories
        def create
          authorize [ :admin, ServiceCategory ]
          category = ServiceCategory.transaction do
            ServiceCategory.create!(category_params).tap do |c|
              ::Admin::Audit.record!(action: "category.created", target: c, changes: c.saved_changes.except("created_at", "updated_at", "id"))
            end
          end
          render_data(serialize(category), status: :created)
        end

        # PATCH /api/v1/admin/categories/:slug — deactivate with { active: false }; nothing is deleted.
        def update
          category = ServiceCategory.kept.find_by!(slug: params[:id])
          authorize [ :admin, category ]
          ServiceCategory.transaction do
            category.update!(category_params)
            ::Admin::Audit.record!(action: "category.updated", target: category, changes: category.saved_changes.except("updated_at"))
          end
          render_data(serialize(category))
        end

        private

        def category_params
          p = params.require(:category).permit(:slug, :icon, :inspection_allowed, :active, :sort, :parent,
                                               name_i18n: %i[en hi pa], description_i18n: %i[en hi pa])
          p[:parent] = (ServiceCategory.kept.find_by!(slug: p[:parent]) if p[:parent].present?) if p.key?(:parent)
          p
        end

        def serialize(c)
          c.slice(:slug, :icon, :inspection_allowed, :active, :sort, :name_i18n, :description_i18n)
           .merge(parent: c.parent&.slug)
        end
      end
    end
  end
end
