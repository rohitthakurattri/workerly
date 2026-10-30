module Ai
  # Versioned prompts from config/ai/prompts/<use_case>.yml.
  module Prompts
    Prompt = Data.define(:version, :system, :user_template, :schema) do
      def render(vars) = format(user_template, **vars)
    end

    def self.fetch(use_case)
      @prompts ||= {}
      @prompts[use_case.to_s] = nil if Rails.env.development? # pick up edits without a restart
      @prompts[use_case.to_s] ||= begin
        yaml = YAML.safe_load_file(Rails.root.join("config/ai/prompts/#{use_case}.yml"))
        Prompt.new(version: yaml.fetch("version"), system: yaml.fetch("system"),
                   user_template: yaml.fetch("user"), schema: yaml.fetch("schema"))
      end
    end
  end
end
