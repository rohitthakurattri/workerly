module Api
  module V1
    module Admin
      class AuditLogsController < BaseController
        TARGET_TYPES = { "WorkerProfile" => WorkerProfile, "ServiceCategory" => ServiceCategory, "User" => User }.freeze

        # GET /api/v1/admin/audit_logs?filter[target_type]=WorkerProfile&filter[target_id]=<public id>
        def index
          authorize [ :admin, AdminAction ]
          scope = AdminAction.includes(:admin)
          if (type = params.dig(:filter, :target_type)).present?
            klass = TARGET_TYPES[type] || raise(ApplicationError.new(:invalid_filter, status: :bad_request, details: { allowed: TARGET_TYPES.keys }))
            scope = scope.where(target_type: type)
            if (pid = params.dig(:filter, :target_id)).present?
              scope = scope.where(target_id: klass.where(public_id_column(klass) => pid).select(:id))
            end
          end

          records, meta = paginate(scope, order: { id: :desc })
          render_data(records.map { |a| ::Admin::AdminActionResource.new(a, params: { target_ids: target_ids(records) }).to_h }, meta:)
        end

        private

        def public_id_column(klass) = klass.column_names.include?("public_id") ? :public_id : :slug

        # One query per target type instead of one per row.
        def target_ids(records)
          @target_ids ||= records.group_by(&:target_type).each_with_object({}) do |(type, rows), map|
            klass = TARGET_TYPES[type] or next
            col = public_id_column(klass)
            klass.where(id: rows.map(&:target_id)).pluck(:id, col).each { |id, pid| map[[ type, id ]] = pid }
          end
        end
      end
    end
  end
end
