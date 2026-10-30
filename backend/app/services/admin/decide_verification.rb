module Admin
  # A verifier's decision on a submitted worker profile, with per-document verdicts.
  # Approval needs every required document approved.
  class DecideVerification
    DECISIONS = %w[approved changes_requested rejected].freeze

    def self.call(...) = new(...).call

    # documents: [{ id: public_id, status: "approved"|"rejected", reason: }]
    def initialize(profile:, decision:, reason: nil, documents: [], auth: Current.auth)
      @profile = profile
      @decision = decision.to_s
      @reason = reason.to_s.strip.presence
      @doc_decisions = Array(documents).map { |d| d.to_h.symbolize_keys }
      @auth = auth
    end

    def call
      validate_input!
      WorkerProfile.transaction do
        @profile.lock!
        unless @profile.pending_review?
          raise ApplicationError.new(:invalid_transition, status: :conflict,
                                     details: { from: @profile.verification_status, to: @decision })
        end

        applied = apply_document_decisions!
        check_approvable! if @decision == "approved"

        before = @profile.verification_status
        @profile.update!(verification_status: @decision, approved_at: (Time.current if @decision == "approved"))
        WorkerVerification.create!(worker_profile: @profile, admin: @auth.user, decision: @decision,
                                   reason: @reason, document_decisions: applied)
        Audit.record!(action: "worker.verification.#{@decision}", target: @profile, reason: @reason,
                      changes: { verification_status: [ before, @decision ], documents: applied })
      end
      Workers::VerificationNotificationJob.perform_later(@profile.id, @decision)
      @profile
    end

    private

    def validate_input!
      raise ApplicationError.new(:invalid_decision, details: { allowed: DECISIONS }) unless DECISIONS.include?(@decision)
      if @decision != "approved" && @reason.nil?
        raise ApplicationError.new(:reason_required, details: { field_errors: { reason: [ "is required" ] } })
      end

      @doc_decisions.each do |d|
        raise ApplicationError.new(:invalid_document_decision) unless %w[approved rejected].include?(d[:status].to_s)
        if d[:status].to_s == "rejected" && d[:reason].to_s.strip.empty?
          raise ApplicationError.new(:reason_required, details: { document: d[:id] })
        end
      end
    end

    def apply_document_decisions!
      docs = @profile.documents.live.index_by(&:public_id)
      @doc_decisions.map do |d|
        doc = docs[d[:id].to_s] || raise(ApplicationError.new(:document_not_found, status: :not_found, details: { id: d[:id] }))
        doc.update!(status: d[:status].to_s, rejection_reason: (d[:reason].to_s.strip if d[:status].to_s == "rejected"),
                    reviewed_by: @auth.user, reviewed_at: Time.current)
        { id: doc.public_id, kind: doc.kind, status: doc.status, reason: doc.rejection_reason }.compact
      end
    end

    def check_approvable!
      pending = @profile.documents.where(status: "pending").pluck(:public_id)
      raise ApplicationError.new(:documents_pending, details: { ids: pending }) if pending.any?

      approved = @profile.documents.where(status: "approved").pluck(:kind)
      missing = WorkerDocument::REQUIRED_KINDS - approved
      return if missing.empty?

      raise ApplicationError.new(:documents_not_approved, status: :unprocessable_content, details: { kinds: missing })
    end
  end
end
