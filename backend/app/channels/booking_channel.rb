# One booking, live, for its customer and its worker (as the role they're signed in with).
class BookingChannel < ApplicationCable::Channel
  def subscribed
    booking = Booking.find_by(public_id: params[:id].to_s)
    allowed = booking && case current_role
                         when "customer" then booking.customer_id == current_user.id
                         when "worker" then booking.worker_profile_id == current_user.worker_profile&.id
                         end
    return reject unless allowed

    stream_for booking
  end
end
