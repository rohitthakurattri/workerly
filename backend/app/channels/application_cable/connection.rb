module ApplicationCable
  # Authenticates with a one-time ticket from POST /api/v1/cable_tickets (?ticket=…), checked
  # against the live session like every API call.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_role, :session_id

    def connect
      claims = Identity::Tokens.decode(request.params[:ticket], typ: "cable")
      reject_unauthorized_connection unless Rails.cache.write("cable_ticket:#{claims['jti']}", 1, unless_exist: true, expires_in: 2.minutes)

      session = UserSession.includes(:user).find_by(public_id: claims["sid"])
      user = session&.user
      reject_unauthorized_connection unless session&.active? && user&.active? && user.public_id == claims["sub"] &&
                                            user.roles_for_scope(session.scope).include?(claims["role"])

      self.current_user = user
      self.current_role = claims["role"]
      self.session_id = session.public_id
    rescue ApplicationError
      reject_unauthorized_connection
    end
  end
end
