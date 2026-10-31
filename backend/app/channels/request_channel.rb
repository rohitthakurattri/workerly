# Quotes arriving on one request, live, for its customer. Same gate as the API: own request only.
class RequestChannel < ApplicationCable::Channel
  def subscribed
    request = current_role == "customer" && current_user.service_requests.where.not(status: "draft").find_by(public_id: params[:id].to_s)
    return reject unless request

    stream_for request
  end
end
