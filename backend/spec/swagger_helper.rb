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
            type: :object, required: %w[id status answers safety_flag urgency photos missing cancellable invited_count quotes_count created_at],
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
              quotes_count: { type: :integer }, booking_id: { type: :string, nullable: true },
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
            type: :object, required: %w[id status category description answers urgency safety_flag locality city distance_band photos invited_at expires_at
                                        currency quotes_count quotes_full],
            properties: {
              id: { type: :string }, status: { type: :string, enum: %w[new viewed quoted declined] },
              category: { type: :object, required: %w[slug name inspection_allowed tax_rate_bps],
                          properties: { slug: { type: :string }, name: { type: :string }, icon: { type: :string, nullable: true },
                                        inspection_allowed: { type: :boolean }, tax_rate_bps: { type: :integer } } },
              currency: { type: :string }, quotes_count: { type: :integer }, quotes_full: { type: :boolean },
              quotation: { allOf: [ { "$ref" => "#/components/schemas/worker_quotation" } ], nullable: true },
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
          money: { type: :object, required: %w[minor currency], properties: { minor: { type: :integer }, currency: { type: :string } } },
          quotation_kind: { type: :string, enum: %w[fixed inspection] },
          quotation_status: { type: :string, enum: %w[submitted accepted declined withdrawn expired] },
          quotation_item: {
            type: :object, required: %w[type description quantity unit unit_price amount],
            properties: { type: { type: :string, enum: %w[labour material transport inspection other] }, description: { type: :string },
                          brand: { type: :string, nullable: true }, quantity: { type: :number },
                          unit: { type: :string, enum: %w[job item hour visit metre sq_ft kg litre] },
                          unit_price: { "$ref" => "#/components/schemas/money" }, amount: { "$ref" => "#/components/schemas/money" },
                          condition: { type: :string, nullable: true, enum: [ "new", "refurbished", "used", nil ] },
                          warranty_days: { type: :integer, nullable: true } }
          },
          quotation_revision: {
            type: :object, required: %w[id version stage subtotal tax_rate_bps tax total items created_at],
            properties: { id: { type: :string }, version: { type: :integer },
                          stage: { type: :string, enum: %w[initial inspection_fee final change_order] },
                          subtotal: { "$ref" => "#/components/schemas/money" }, tax_rate_bps: { type: :integer },
                          tax: { "$ref" => "#/components/schemas/money" }, total: { "$ref" => "#/components/schemas/money" },
                          notes: { type: :string, nullable: true }, estimated_minutes: { type: :integer, nullable: true },
                          items: { type: :array, items: { "$ref" => "#/components/schemas/quotation_item" } }, created_at: { type: :string } }
          },
          quotation_input: {
            type: :object, required: %w[kind],
            properties: { kind: { "$ref" => "#/components/schemas/quotation_kind" },
                          items: { type: :array, items: { type: :object, required: %w[type description quantity unit unit_price_minor],
                            properties: { type: { type: :string }, description: { type: :string }, brand: { type: :string },
                                          quantity: { type: :number }, unit: { type: :string }, unit_price_minor: { type: :integer },
                                          condition: { type: :string }, warranty_days: { type: :integer } } } },
                          inspection_fee_minor: { type: :integer }, notes: { type: :string }, estimated_minutes: { type: :integer },
                          valid_until: { type: :string } }
          },
          worker_card: {
            type: :object, required: %w[id name rating_count verified jobs_done],
            properties: { id: { type: :string }, name: { type: :string, nullable: true }, photo: { "$ref" => "#/components/schemas/file" },
                          rating_avg: { type: :number, nullable: true }, rating_count: { type: :integer },
                          experience_years: { type: :integer, nullable: true }, verified: { type: :boolean }, jobs_done: { type: :integer },
                          phone: { type: :string } }
          },
          quotation: {
            type: :object, required: %w[id kind status current_version valid_until submitted_at revised revision worker distance_band],
            properties: { id: { type: :string }, kind: { "$ref" => "#/components/schemas/quotation_kind" },
                          status: { "$ref" => "#/components/schemas/quotation_status" }, current_version: { type: :integer },
                          valid_until: { type: :string }, submitted_at: { type: :string }, revised: { type: :boolean },
                          revision: { "$ref" => "#/components/schemas/quotation_revision" },
                          worker: { "$ref" => "#/components/schemas/worker_card" },
                          distance_band: { type: :string, enum: %w[under_1km 1_3km 3_5km 5_10km over_10km] },
                          booking_id: { type: :string, nullable: true }, decline_reason: { type: :string, nullable: true },
                          revisions: { type: :array, items: { type: :object, required: %w[version total created_at],
                            properties: { version: { type: :integer }, total: { "$ref" => "#/components/schemas/money" }, created_at: { type: :string } } } } }
          },
          worker_quotation: {
            type: :object, required: %w[id lead_id kind status current_version valid_until submitted_at revision category locality editable],
            properties: { id: { type: :string }, lead_id: { type: :string }, kind: { "$ref" => "#/components/schemas/quotation_kind" },
                          status: { "$ref" => "#/components/schemas/quotation_status" }, current_version: { type: :integer },
                          valid_until: { type: :string }, submitted_at: { type: :string },
                          revision: { "$ref" => "#/components/schemas/quotation_revision" },
                          category: { "$ref" => "#/components/schemas/category_brief" }, locality: { type: :string },
                          editable: { type: :boolean }, booking_id: { type: :string, nullable: true },
                          decline_reason: { type: :string, nullable: true } }
          },
          booking_status: { type: :string, enum: %w[confirmed inspection_scheduled inspecting awaiting_final_approval closed_after_inspection
                                                    scheduled in_progress awaiting_change_approval completed paid cancelled rejected disputed refunded] },
          booking_address: {
            type: :object, nullable: true,
            properties: { label: { type: :string, nullable: true }, line1: { type: :string }, line2: { type: :string, nullable: true },
                          landmark: { type: :string, nullable: true }, locality: { type: :string }, pincode: { type: :string },
                          city: { type: :string }, location: { "$ref" => "#/components/schemas/lat_lng" } }
          },
          booking_event: { type: :string, enum: Bookings::Transitions::EVENTS.map(&:to_s) },
          booking: {
            type: :object, required: %w[id status kind request_id category approved_total revision quotation_id confirmed_at
                                        approvals history actions contact_visible chat_open paid outstanding payable payments],
            properties: { id: { type: :string }, status: { "$ref" => "#/components/schemas/booking_status" },
                          kind: { "$ref" => "#/components/schemas/quotation_kind" }, request_id: { type: :string },
                          category: { "$ref" => "#/components/schemas/category_brief" },
                          approved_total: { allOf: [ { "$ref" => "#/components/schemas/money" } ], description: "What the customer owes: approved revisions only" },
                          revision: { "$ref" => "#/components/schemas/quotation_revision" }, quotation_id: { type: :string },
                          pending_revision: { allOf: [ { "$ref" => "#/components/schemas/quotation_revision" } ], nullable: true },
                          approvals: { type: :array, items: { type: :object, required: %w[revision_id version stage decision total decided_at],
                            properties: { revision_id: { type: :string }, version: { type: :integer }, stage: { type: :string },
                                          decision: { type: :string, enum: %w[approved rejected] }, total: { "$ref" => "#/components/schemas/money" },
                                          decided_at: { type: :string } } } },
                          history: { type: :array, items: { type: :object, required: %w[to at],
                            properties: { from: { type: :string, nullable: true }, to: { type: :string }, event: { type: :string, nullable: true },
                                          by: { type: :string, nullable: true }, at: { type: :string } } } },
                          preferred_from: { type: :string, nullable: true }, preferred_to: { type: :string, nullable: true },
                          confirmed_at: { type: :string }, scheduled_at: { type: :string, nullable: true },
                          checked_in_at: { type: :string, nullable: true }, started_at: { type: :string, nullable: true },
                          completed_at: { type: :string, nullable: true }, cancelled_at: { type: :string, nullable: true },
                          cancelled_by: { type: :string, nullable: true }, cancel_reason: { type: :string, nullable: true },
                          paid: { "$ref" => "#/components/schemas/money" }, outstanding: { "$ref" => "#/components/schemas/money" },
                          payable: { type: :boolean }, invoice_number: { type: :string, nullable: true },
                          payments: { type: :array, items: { "$ref" => "#/components/schemas/payment" } },
                          contact_visible: { type: :boolean }, chat_open: { type: :boolean },
                          actions: { type: :array, items: { "$ref" => "#/components/schemas/booking_event" } },
                          review: { type: :object, nullable: true, properties: { rating: { type: :integer }, body: { type: :string, nullable: true }, created_at: { type: :string } } },
                          dispute: { type: :object, nullable: true,
                                     properties: { id: { type: :string }, category: { type: :string }, description: { type: :string },
                                                   status: { type: :string, enum: %w[open resolved] }, resolution: { type: :string, nullable: true },
                                                   created_at: { type: :string }, resolved_at: { type: :string, nullable: true } } },
                          address: { "$ref" => "#/components/schemas/booking_address" } }
          },
          payment: {
            type: :object, required: %w[id method provider status amount refunded created_at],
            properties: { id: { type: :string }, method: { type: :string, enum: %w[online cash] }, provider: { type: :string },
                          status: { type: :string, enum: Payment::STATUSES }, amount: { "$ref" => "#/components/schemas/money" },
                          refunded: { "$ref" => "#/components/schemas/money" }, captured_at: { type: :string, nullable: true },
                          created_at: { type: :string } }
          },
          payment_order: {
            type: :object, required: %w[payment checkout],
            properties: { payment: { "$ref" => "#/components/schemas/payment" },
                          checkout: { type: :object, required: %w[provider key_id order_id amount currency],
                                      properties: { provider: { type: :string, enum: %w[fake razorpay] }, key_id: { type: :string, nullable: true },
                                                    order_id: { type: :string }, amount: { type: :integer }, currency: { type: :string },
                                                    name: { type: :string }, description: { type: :string },
                                                    prefill: { type: :object, properties: { contact: { type: :string } } } } } }
          },
          invoice: {
            type: :object, required: %w[id number booking_id issued_at subtotal tax total lines parties],
            properties: { id: { type: :string }, number: { type: :string }, booking_id: { type: :string }, issued_at: { type: :string },
                          subtotal: { "$ref" => "#/components/schemas/money" }, tax: { "$ref" => "#/components/schemas/money" },
                          total: { "$ref" => "#/components/schemas/money" },
                          lines: { type: :array, items: { type: :object, properties: { stage: { type: :string }, type: { type: :string }, description: { type: :string },
                                                                                       quantity: { type: :number }, unit: { type: :string },
                                                                                       unit_price_minor: { type: :integer }, amount_minor: { type: :integer } } } },
                          parties: { type: :object, additionalProperties: true } }
          },
          earnings: {
            type: :object, required: %w[balance jobs payouts],
            properties: {
              balance: { type: :object, required: %w[held owed net], properties: { held: { "$ref" => "#/components/schemas/money" },
                                                                                  owed: { "$ref" => "#/components/schemas/money" },
                                                                                  net: { "$ref" => "#/components/schemas/money" } } },
              jobs: { type: :array, items: { type: :object, required: %w[booking_id category method amount commission tax earnings refunded paid_at],
                properties: { booking_id: { type: :string }, category: { type: :string }, method: { type: :string },
                              amount: { "$ref" => "#/components/schemas/money" }, commission: { "$ref" => "#/components/schemas/money" },
                              tax: { "$ref" => "#/components/schemas/money" }, earnings: { "$ref" => "#/components/schemas/money" },
                              refunded: { "$ref" => "#/components/schemas/money" }, paid_at: { type: :string } } } },
              payouts: { type: :array, items: { type: :object, required: %w[id amount reference paid_at],
                properties: { id: { type: :string }, amount: { "$ref" => "#/components/schemas/money" }, reference: { type: :string }, paid_at: { type: :string } } } }
            }
          },
          admin_payment: {
            allOf: [ { "$ref" => "#/components/schemas/payment" },
                     { type: :object, required: %w[booking_id refundable refunds],
                       properties: { booking_id: { type: :string }, customer_name: { type: :string, nullable: true }, worker_name: { type: :string, nullable: true },
                                     commission: { allOf: [ { "$ref" => "#/components/schemas/money" } ], nullable: true },
                                     worker_share: { allOf: [ { "$ref" => "#/components/schemas/money" } ], nullable: true },
                                     refundable: { "$ref" => "#/components/schemas/money" },
                                     refunds: { type: :array, items: { type: :object, required: %w[id amount status reason],
                                                                                         properties: { id: { type: :string }, amount: { "$ref" => "#/components/schemas/money" },
                                                                                                       status: { type: :string, enum: %w[pending processed failed] },
                                                                                                       reason: { type: :string } } } } } } ]
          },
          worker_balance: {
            type: :object, required: %w[worker_id held owed net],
            properties: { worker_id: { type: :string }, name: { type: :string, nullable: true }, phone: { type: :string },
                          held: { "$ref" => "#/components/schemas/money" }, owed: { "$ref" => "#/components/schemas/money" }, net: { "$ref" => "#/components/schemas/money" } }
          },
          reconciliation: {
            type: :object, required: %w[currency from to online_captured_minor cash_recorded_minor refunded_minor payouts_minor commission_minor
                                         tax_minor balances ledger_balanced ledger_debits_minor ledger_credits_minor issues],
            properties: { currency: { type: :string }, from: { type: :string }, to: { type: :string },
                          online_captured_minor: { type: :integer }, cash_recorded_minor: { type: :integer }, refunded_minor: { type: :integer },
                          payouts_minor: { type: :integer }, commission_minor: { type: :integer }, tax_minor: { type: :integer },
                          balances: { type: :object, additionalProperties: { type: :integer } }, ledger_balanced: { type: :boolean },
                          ledger_debits_minor: { type: :integer }, ledger_credits_minor: { type: :integer },
                          issues: { type: :object, required: %w[payments_without_ledger amount_mismatches pending_refunds stale_orders],
                                    properties: { payments_without_ledger: { type: :array, items: { type: :string } },
                                                                 amount_mismatches: { type: :array, items: { type: :string } },
                                                                 pending_refunds: { type: :array, items: { type: :string } },
                                                                 stale_orders: { type: :integer } } } }
          },
          commission_rule: {
            type: :object, required: %w[id percent_bps fixed_minor effective_from],
            properties: { id: { type: :integer }, city: { type: :string, nullable: true }, category: { type: :string, nullable: true },
                          percent_bps: { type: :integer }, fixed_minor: { type: :integer }, effective_from: { type: :string } }
          },
          message: {
            type: :object, required: %w[id sender_role body created_at],
            properties: { id: { type: :string }, sender_role: { type: :string, enum: %w[customer worker] }, sender_name: { type: :string, nullable: true },
                          body: { type: :string }, created_at: { type: :string } }
          },
          admin_booking_summary: {
            type: :object, required: %w[id status kind category approved_total confirmed_at],
            properties: { id: { type: :string }, status: { "$ref" => "#/components/schemas/booking_status" }, kind: { "$ref" => "#/components/schemas/quotation_kind" },
                          category: { type: :string }, locality: { type: :string, nullable: true }, customer_name: { type: :string, nullable: true },
                          worker_name: { type: :string, nullable: true }, approved_total: { "$ref" => "#/components/schemas/money" },
                          confirmed_at: { type: :string }, scheduled_at: { type: :string, nullable: true }, updated_at: { type: :string } }
          },
          admin_booking: {
            allOf: [ { "$ref" => "#/components/schemas/booking" },
                     { type: :object, required: %w[customer worker messages],
                       properties: { customer: { type: :object, properties: { id: { type: :string }, name: { type: :string, nullable: true }, phone: { type: :string } } },
                                     worker: { type: :object, properties: { id: { type: :string }, name: { type: :string, nullable: true }, phone: { type: :string } } },
                                     locality: { type: :string, nullable: true },
                                     messages: { type: :array, items: { "$ref" => "#/components/schemas/message" } } } } ]
          },
          admin_dispute: {
            type: :object, required: %w[id category description status booking_id booking_status created_at],
            properties: { id: { type: :string }, category: { type: :string }, description: { type: :string }, status: { type: :string, enum: %w[open resolved] },
                          resolution: { type: :string, nullable: true }, booking_id: { type: :string }, booking_status: { "$ref" => "#/components/schemas/booking_status" },
                          approved_total: { "$ref" => "#/components/schemas/money" }, customer_name: { type: :string, nullable: true },
                          worker_name: { type: :string, nullable: true }, created_at: { type: :string }, resolved_at: { type: :string, nullable: true } }
          },
          customer_booking: {
            allOf: [ { "$ref" => "#/components/schemas/booking" },
                     { type: :object, required: %w[worker can_review can_dispute],
                       properties: { worker: { "$ref" => "#/components/schemas/worker_card" }, can_review: { type: :boolean }, can_dispute: { type: :boolean } } } ]
          },
          worker_booking: {
            allOf: [ { "$ref" => "#/components/schemas/booking" },
                     { type: :object, required: %w[answers urgency photos currency tax_rate_bps],
                       properties: { customer: { type: :object, nullable: true, properties: { name: { type: :string, nullable: true }, phone: { type: :string } } },
                                     description: { type: :string, nullable: true }, urgency: { "$ref" => "#/components/schemas/urgency" },
                                     answers: { type: :array, items: { type: :object, properties: { question: { type: :string }, answer: { type: :string } } } },
                                     photos: { type: :array, items: { "$ref" => "#/components/schemas/request_photo" } },
                                     currency: { type: :string }, tax_rate_bps: { type: :integer } } } ]
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
                          quotes_count: { type: :integer },
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
                              decline_reason: { type: :string, nullable: true } } } },
              quotations: { type: :array, items: { type: :object, required: %w[id worker_id kind status current_version revisions],
                properties: { id: { type: :string }, worker_id: { type: :string }, worker_name: { type: :string, nullable: true },
                              kind: { "$ref" => "#/components/schemas/quotation_kind" }, status: { "$ref" => "#/components/schemas/quotation_status" },
                              current_version: { type: :integer }, valid_until: { type: :string }, decline_reason: { type: :string, nullable: true },
                              accepted_at: { type: :string, nullable: true }, withdrawn_at: { type: :string, nullable: true },
                              revisions: { type: :array, items: { "$ref" => "#/components/schemas/quotation_revision" } } } } },
              booking: { type: :object, nullable: true,
                         properties: { id: { type: :string }, status: { "$ref" => "#/components/schemas/booking_status" },
                                       kind: { "$ref" => "#/components/schemas/quotation_kind" }, worker_id: { type: :string },
                                       approved_total: { "$ref" => "#/components/schemas/money" }, confirmed_at: { type: :string } } }
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
