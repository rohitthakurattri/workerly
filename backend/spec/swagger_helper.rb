require "rails_helper"

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s
  config.openapi_format = :yaml
  config.openapi_specs = {
    "v1/openapi.yaml" => {
      openapi: "3.0.3",
      info: { title: "Workerly API", version: "v1" },
      servers: [ { url: "http://localhost:3000" }, { url: "https://api.workerly.in" } ],
      components: {
        securitySchemes: { bearer: { type: :http, scheme: :bearer, bearerFormat: "JWT" } },
        schemas: {
          error: {
            type: :object, required: %w[error],
            properties: { error: { type: :object, required: %w[code message request_id],
                                   properties: { code: { type: :string }, message: { type: :string },
                                                 details: { type: :object }, request_id: { type: :string } } } }
          },
          user: {
            type: :object, required: %w[id phone roles locale],
            properties: { id: { type: :string, format: :uuid }, phone: { type: :string }, name: { type: :string, nullable: true },
                          email: { type: :string, nullable: true }, locale: { type: :string, enum: %w[en hi pa] },
                          roles: { type: :array, items: { type: :string } }, created_at: { type: :string, format: "date-time" } }
          },
          auth_session: {
            type: :object, required: %w[data],
            properties: { data: { type: :object, required: %w[access_token token_type expires_in active_role session user],
                                  properties: { access_token: { type: :string }, token_type: { type: :string },
                                                expires_in: { type: :integer }, refresh_token: { type: :string },
                                                active_role: { type: :string },
                                                session: { type: :object, properties: { scope: { type: :string }, expires_at: { type: :string } } },
                                                user: { "$ref" => "#/components/schemas/user" } } } }
          }
        }
      }
    }
  }
end
