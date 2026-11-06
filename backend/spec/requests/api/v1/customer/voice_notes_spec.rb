require "rails_helper"

RSpec.describe "Voice notes", type: :request do
  let!(:mohali) { create(:mohali) }
  let!(:plumber) { create(:plumber) }
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }
  let(:draft) { create(:service_request, customer: user, description: "Help") }

  def upload(name = "voice.webm", type = "audio/webm", request: draft, duration_ms: 4200)
    post("/api/v1/customer/service_requests/#{request.public_id}/voice_note",
         params: { file: fixture(name, type), duration_ms: }, headers: multipart_headers(headers))
  end

  def attach_voice_note!(request, transcript:)
    request.attachments.create!(kind: "audio", transcript:, transcript_status: "succeeded", duration_ms: 3000,
                                file: { io: File.open(file_fixture("voice.webm")), filename: "v.webm", content_type: "audio/webm", identify: false })
  end

  it "stores the recording and transcribes it in the background through the AI gateway" do
    expect { upload }.to have_enqueued_job(Requests::TranscribeVoiceNoteJob)
    expect(response).to have_http_status(:created)
    expect(json["data"]).to include("transcript_status" => "pending", "duration_ms" => 4200, "transcript" => nil)
    expect(json.dig("data", "file", "content_type")).to eq("audio/webm")

    perform_enqueued_jobs
    get("/api/v1/customer/service_requests/#{draft.public_id}", headers:)
    expect(json.dig("data", "voice_note")).to include("transcript_status" => "succeeded", "transcript_language" => "en",
                                                      "transcript" => Adapters::Ai::Fake::TRANSCRIPTS["en"])
    expect(json.dig("data", "photos")).to eq([]) # a voice note isn't a photo
    expect(AiAnalysis.sole).to have_attributes(use_case: "transcribe", status: "succeeded", provider: "fake",
                                               prompt_version: start_with("transcribe-"), analysable: draft)
  end

  it "transcribes in the customer's language" do
    user.update!(locale: "hi")
    upload
    perform_enqueued_jobs
    expect(draft.reload.voice_note).to have_attributes(transcript: Adapters::Ai::Fake::TRANSCRIPTS["hi"], transcript_language: "hi")
  end

  it "keeps one voice note per request: a new recording replaces the old one" do
    upload
    first = json.dig("data", "id")
    upload
    expect(draft.attachments.voice_notes.pluck(:public_id)).to eq([ json.dig("data", "id") ])
    expect(json.dig("data", "id")).not_to eq(first)
  end

  it "refuses files that are not recordings by their bytes, whatever the name, and big files" do
    upload("renamed.jpg", "audio/webm")
    expect([ response.status, json.dig("error", "details", "field_errors", "file") ]).to eq([ 422, [ "must be a voice recording (WebM, Ogg, MP4 or MP3)" ] ])

    big = Tempfile.new([ "big", ".webm" ])
    big.binmode
    big.write(file_fixture("voice.webm").binread + ("\0" * 3.1.megabytes))
    big.flush
    post("/api/v1/customer/service_requests/#{draft.public_id}/voice_note",
         params: { file: Rack::Test::UploadedFile.new(big.path, "audio/webm") }, headers: multipart_headers(headers))
    expect(json.dig("error", "details", "field_errors", "file")).to eq([ "must be smaller than 3 MB" ])
  ensure
    big&.close!
  end

  it "only changes drafts, and only the customer's own" do
    upload(request: create(:service_request, :open, customer: user))
    expect([ response.status, error_code ]).to eq([ 403, "request_locked" ]) # same as photos
    upload(request: create(:service_request))
    expect(response).to have_http_status(:not_found)
  end

  it "is deleted like a photo" do
    upload
    delete("/api/v1/customer/service_requests/#{draft.public_id}/attachments/#{json.dig('data', 'id')}", headers:)
    expect(response).to have_http_status(:no_content)
    expect(draft.attachments.voice_notes).to be_empty
  end

  it "skips transcription when the flag is off" do
    with_config(ai_transcribe_enabled: false)
    expect { upload }.not_to have_enqueued_job(Requests::TranscribeVoiceNoteJob)
    expect(json.dig("data", "transcript_status")).to eq("skipped")
  end

  it "marks the transcript failed (recording kept) when the provider is unavailable" do
    upload
    allow_any_instance_of(Adapters::Ai::Fake).to receive(:transcribe).and_raise(Adapters::Ai::Error.new(:timeout)) # rubocop:disable RSpec/AnyInstance
    perform_enqueued_jobs
    expect(draft.reload.voice_note).to have_attributes(transcript_status: "failed", transcript: nil)
    expect(draft.voice_note.file).to be_attached
  end

  it "lets triage read the transcript when the description is too short on its own" do
    upload
    perform_enqueued_jobs
    post("/api/v1/customer/service_requests/#{draft.public_id}/triage", headers:)
    expect(json.dig("data", "suggested_category", "slug")).to eq("plumber")
  end

  describe "what workers get" do
    let!(:worker) { create(:worker_profile, :matchable) }
    let(:worker_headers) { auth_headers_for(worker.user, role: "worker") }

    it "shows an invited worker the redacted transcript but not the recording" do
      request = create(:service_request, :open, customer: user)
      attach_voice_note!(request, transcript: "Tap is leaking, call me on 98765 43210")
      Matching::InviteWorkers.call(request)

      get("/api/v1/worker/leads/#{request.public_id}", headers: worker_headers)
      expect(json.dig("data", "voice_note")).to include("transcript" => "Tap is leaking, call me on [phone removed]", "file" => nil)
      expect(response.body).not_to include("98765")
    end

    it "gives the booked worker the recording and the customer's own words while contact is open" do
      booking = booked!(customer: user)
      attach_voice_note!(booking.service_request, transcript: "Call me on 98765 43210")

      get("/api/v1/worker/bookings/#{booking.public_id}", headers: auth_headers_for(booking.worker_profile.user, role: "worker"))
      expect(json.dig("data", "voice_note", "transcript")).to eq("Call me on 98765 43210")
      expect(json.dig("data", "voice_note", "file", "content_type")).to eq("audio/webm")
    end
  end
end
