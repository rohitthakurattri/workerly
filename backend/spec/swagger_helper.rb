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
          category_brief: {
            type: :object, required: %w[slug name],
            properties: { slug: { type: :string }, name: { type: :string }, icon: { type: :string, nullable: true } }
          },
          address: {
            type: :object, required: %w[id line1 locality pincode city location is_default],
            properties: { id: { type: :string }, label: { type: :string, nullable: true }, line1: { type: :string },
                          line2: { type: :string, nullable: true }, landmark: { type: :string, nullable: true },
                          locality: { type: :string }, pincode: { type: :string }, city: { type: :string },
                          is_default: { type: :boolean }, location: { "$ref" => "#/components/schemas/lat_lng" } }
          },
          request_status: { type: :string, enum: %w[draft open quoting booked fulfilled expired cancelled] },
          urgency: { type: :string, enum: %w[asap today this_week flexible] },
          request_photo: {
            type: :object, required: %w[id kind file],
            properties: { id: { type: :string }, kind: { type: :string, enum: %w[image audio video] },
                          width: { type: :integer, nullable: true }, height: { type: :integer, nullable: true },
                          file: { "$ref" => "#/components/schemas/file" } }
          },
          triage: {
            type: :object, required: %w[id confidence alternatives questions safety_flag needs_confirmation],
            properties: { id: { type: :string }, suggested_category: { allOf: [ { "$ref" => "#/components/schemas/category_brief" } ], nullable: true },
                          confidence: { type: :number }, summary: { type: :string, nullable: true },
                          questions: { type: :array, items: { type: :string } },
                          urgency: { allOf: [ { "$ref" => "#/components/schemas/urgency" } ], nullable: true },
                          safety_flag: { type: :boolean }, needs_confirmation: { type: :boolean },
                          alternatives: { type: :array, items: { "$ref" => "#/components/schemas/category_brief" } } }
          },
          service_request: {
            type: :object, required: %w[id status answers safety_flag urgency photos missing cancellable invited_count created_at],
            properties: {
              id: { type: :string }, status: { "$ref" => "#/components/schemas/request_status" },
              description: { type: :string, nullable: true },
              answers: { type: :array, items: { type: :object, required: %w[question answer], properties: { question: { type: :string }, answer: { type: :string } } } },
              ai_summary: { type: :string, nullable: true }, safety_flag: { type: :boolean },
              urgency: { "$ref" => "#/components/schemas/urgency" },
              category_source: { type: :string, enum: %w[ai customer], nullable: true },
              category: { allOf: [ { "$ref" => "#/components/schemas/category_brief" } ], nullable: true },
              address: { allOf: [ { "$ref" => "#/components/schemas/address" } ], nullable: true },
              preferred_from: { type: :string, nullable: true }, preferred_to: { type: :string, nullable: true },
              photos: { type: :array, items: { "$ref" => "#/components/schemas/request_photo" } },
              triage: { allOf: [ { "$ref" => "#/components/schemas/triage" } ], nullable: true },
              missing: { type: :array, items: { type: :string, enum: %w[description category address] } },
              cancellable: { type: :boolean }, cancel_reason: { type: :string, nullable: true },
              invited_count: { type: :integer }, matched_at: { type: :string, nullable: true },
              created_at: { type: :string }, submitted_at: { type: :string, nullable: true },
              expires_at: { type: :string, nullable: true }, cancelled_at: { type: :string, nullable: true }
            }
          },
          service_request_summary: {
            type: :object, required: %w[id status urgency photo_count created_at],
            properties: { id: { type: :string }, status: { "$ref" => "#/components/schemas/request_status" },
                          urgency: { "$ref" => "#/components/schemas/urgency" }, title: { type: :string, nullable: true },
                          category: { allOf: [ { "$ref" => "#/components/schemas/category_brief" } ], nullable: true },
                          locality: { type: :string, nullable: true }, photo_count: { type: :integer },
                          cover: { "$ref" => "#/components/schemas/file" }, created_at: { type: :string },
                          submitted_at: { type: :string, nullable: true }, expires_at: { type: :string, nullable: true } }
          },
          lead: {
            type: :object, required: %w[id status category description answers urgency safety_flag locality city distance_band photos invited_at expires_at],
            properties: {
              id: { type: :string }, status: { type: :string, enum: %w[new viewed declined] },
              category: { "$ref" => "#/components/schemas/category_brief" },
              description: { type: :string, nullable: true }, ai_summary: { type: :string, nullable: true },
              answers: { type: :array, items: { type: :object, required: %w[question answer], properties: { question: { type: :string }, answer: { type: :string } } } },
              urgency: { "$ref" => "#/components/schemas/urgency" }, safety_flag: { type: :boolean },
              preferred_from: { type: :string, nullable: true }, preferred_to: { type: :string, nullable: true },
              locality: { type: :string }, city: { type: :string },
              distance_band: { type: :string, enum: %w[under_1km 1_3km 3_5km 5_10km over_10km] },
              photos: { type: :array, items: { "$ref" => "#/components/schemas/request_photo" } },
              invited_at: { type: :string }, expires_at: { type: :string }
            }
          },
          notification: {
            type: :object, required: %w[id kind title read created_at],
            properties: { id: { type: :string }, kind: { type: :string }, title: { type: :string }, body: { type: :string, nullable: true },
                          url: { type: :string, nullable: true }, data: { type: :object }, read: { type: :boolean }, created_at: { type: :string } }
          },
          admin_service_request_summary: {
            type: :object, required: %w[id status category city invited_count submitted_at],
            properties: { id: { type: :string }, status: { "$ref" => "#/components/schemas/request_status" },
                          urgency: { "$ref" => "#/components/schemas/urgency" }, invited_count: { type: :integer }, safety_flag: { type: :boolean },
                          category: { type: :string }, city: { type: :string }, locality: { type: :string, nullable: true },
                          customer: { type: :object, properties: { name: { type: :string, nullable: true }, phone: { type: :string } } },
                          submitted_at: { type: :string }, matched_at: { type: :string, nullable: true }, expires_at: { type: :string } }
          },
          admin_service_request_detail: {
            type: :object, required: %w[id status category invitations],
            properties: {
              id: { type: :string }, status: { "$ref" => "#/components/schemas/request_status" }, urgency: { "$ref" => "#/components/schemas/urgency" },
              description: { type: :string, nullable: true }, ai_summary: { type: :string, nullable: true }, safety_flag: { type: :boolean },
              category_source: { type: :string, nullable: true }, invited_count: { type: :integer }, cancel_reason: { type: :string, nullable: true },
              answers: { type: :array, items: { type: :object, properties: { question: { type: :string }, answer: { type: :string } } } },
              address_snapshot: { type: :object, properties: { label: { type: :string, nullable: true }, line1: { type: :string }, line2: { type: :string, nullable: true },
                                                                landmark: { type: :string, nullable: true }, locality: { type: :string }, pincode: { type: :string } } },
              category: { type: :string }, city: { type: :string }, location: { "$ref" => "#/components/schemas/lat_lng" },
              customer: { type: :object, properties: { id: { type: :string }, name: { type: :string, nullable: true }, phone: { type: :string } } },
              photos: { type: :array, items: { "$ref" => "#/components/schemas/request_photo" } },
              preferred_from: { type: :string, nullable: true }, preferred_to: { type: :string, nullable: true },
              submitted_at: { type: :string }, matched_at: { type: :string, nullable: true }, expires_at: { type: :string },
              cancelled_at: { type: :string, nullable: true },
              invitations: { type: :array, items: { type: :object, required: %w[rank score distance_m worker_id],
                properties: { rank: { type: :integer }, score: { type: :number }, distance_m: { type: :integer }, worker_id: { type: :string },
                              worker_name: { type: :string, nullable: true }, notified_at: { type: :string, nullable: true },
                              notified_via: { type: :string, nullable: true, enum: [ "push", "sms", "none", nil ] },
                              viewed_at: { type: :string, nullable: true }, declined_at: { type: :string, nullable: true },
                              decline_reason: { type: :string, nullable: true } } } }
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
