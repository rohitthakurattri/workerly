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
          file: {
            type: :object, nullable: true,
            properties: { url: { type: :string }, content_type: { type: :string }, byte_size: { type: :integer },
                          filename: { type: :string }, expires_in: { type: :integer } }
          },
          category: {
            type: :object, required: %w[slug name children],
            properties: { slug: { type: :string }, name: { type: :string }, description: { type: :string, nullable: true },
                          icon: { type: :string, nullable: true }, inspection_allowed: { type: :boolean },
                          children: { type: :array, items: { "$ref" => "#/components/schemas/category" } } }
          },
          city: {
            type: :object, required: %w[slug name center],
            properties: { slug: { type: :string }, name: { type: :string }, state: { type: :string },
                          currency_code: { type: :string }, time_zone: { type: :string }, service_radius_m: { type: :integer },
                          center: { "$ref" => "#/components/schemas/lat_lng" } }
          },
          lat_lng: { type: :object, required: %w[lat lng], properties: { lat: { type: :number }, lng: { type: :number } } },
          service_area: {
            type: :object, required: %w[id city center radius_m],
            properties: { id: { type: :string }, city: { type: :string }, label: { type: :string, nullable: true },
                          radius_m: { type: :integer }, center: { "$ref" => "#/components/schemas/lat_lng" } }
          },
          worker_document: {
            type: :object, required: %w[id kind doc_type status],
            properties: { id: { type: :string }, kind: { type: :string, enum: %w[identity address trade] }, doc_type: { type: :string },
                          number_last4: { type: :string, nullable: true },
                          status: { type: :string, enum: %w[pending approved rejected superseded] },
                          rejection_reason: { type: :string, nullable: true }, reviewed_at: { type: :string, nullable: true },
                          uploaded_at: { type: :string }, file: { "$ref" => "#/components/schemas/file" } }
          },
          verification_status: { type: :string, enum: %w[draft pending_review changes_requested approved rejected] },
          worker_profile: {
            type: :object, required: %w[id verification_status editable suspended skills service_areas documents missing],
            properties: {
              id: { type: :string }, bio: { type: :string, nullable: true }, experience_years: { type: :integer, nullable: true },
              verification_status: { "$ref" => "#/components/schemas/verification_status" },
              available: { type: :boolean }, editable: { type: :boolean }, suspended: { type: :boolean },
              rating_avg: { type: :number, nullable: true }, rating_count: { type: :integer },
              submitted_at: { type: :string, nullable: true }, approved_at: { type: :string, nullable: true },
              photo: { "$ref" => "#/components/schemas/file" },
              skills: { type: :array, items: { type: :object, properties: { category: { type: :string }, name: { type: :string }, experience_years: { type: :integer, nullable: true } } } },
              service_areas: { type: :array, items: { "$ref" => "#/components/schemas/service_area" } },
              documents: { type: :array, items: { "$ref" => "#/components/schemas/worker_document" } },
              missing: { type: :array, items: { type: :string } },
              last_decision: { type: :object, nullable: true, properties: { decision: { type: :string }, reason: { type: :string, nullable: true }, decided_at: { type: :string } } }
            }
          },
          admin_worker_summary: {
            type: :object,
            properties: { id: { type: :string }, name: { type: :string, nullable: true }, phone: { type: :string },
                          verification_status: { "$ref" => "#/components/schemas/verification_status" },
                          experience_years: { type: :integer, nullable: true }, suspended: { type: :boolean },
                          skills: { type: :array, items: { type: :string } },
                          submitted_at: { type: :string, nullable: true }, created_at: { type: :string } }
          },
          admin_worker_detail: {
            type: :object,
            properties: {
              id: { type: :string }, bio: { type: :string, nullable: true }, experience_years: { type: :integer, nullable: true },
              verification_status: { "$ref" => "#/components/schemas/verification_status" },
              suspended: { type: :boolean }, suspension_reason: { type: :string, nullable: true },
              submitted_at: { type: :string, nullable: true }, approved_at: { type: :string, nullable: true },
              user: { type: :object, properties: { id: { type: :string }, name: { type: :string, nullable: true }, phone: { type: :string }, created_at: { type: :string } } },
              photo: { "$ref" => "#/components/schemas/file" },
              skills: { type: :array, items: { type: :object, properties: { category: { type: :string }, name: { type: :string }, experience_years: { type: :integer, nullable: true } } } },
              service_areas: { type: :array, items: { "$ref" => "#/components/schemas/service_area" } },
              documents: { type: :array, items: { "$ref" => "#/components/schemas/worker_document" } },
              missing: { type: :array, items: { type: :string } },
              history: { type: :array, items: { type: :object, properties: { decision: { type: :string }, reason: { type: :string, nullable: true }, documents: { type: :array, items: { type: :object } }, by: { type: :string }, at: { type: :string } } } }
            }
          },
          page_meta: { type: :object, properties: { next_cursor: { type: :string, nullable: true } } },
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
