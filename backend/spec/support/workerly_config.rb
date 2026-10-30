module WorkerlyConfigHelpers
  # Overrides runtime settings for one example: with_config(ai_triage_enabled: false)
  def with_config(**overrides)
    config = Workerly::Config.new(**Workerly.config.to_h.merge(overrides)).freeze
    allow(Workerly).to receive(:config).and_return(config)
  end
end

RSpec.configure { |c| c.include WorkerlyConfigHelpers }
