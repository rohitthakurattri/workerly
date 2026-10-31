class CustomerBookingResource < BookingResource
  attribute(:worker) do |b|
    card = QuotationResource::WorkerCard.call(b.worker_profile)
    b.contact_revealed? ? card.merge(phone: b.worker_profile.user.phone_e164) : card
  end
end
