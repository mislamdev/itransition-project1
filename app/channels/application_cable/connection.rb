module ApplicationCable
  # The connection of the Action Cable server.
  #
  # The application does not need a special connection: everybody may watch
  # the streams, only the signed in users may write.  The identity of the
  # user is read from the session, so that a stream may be limited to the
  # people that are allowed to see it.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    # The user of the session, or nil for a guest.
    def find_verified_user
      user_id = cookies.encrypted[Rails.application.config.session_options[:key]]&.dig("session_id")
      user_id ||= request.session&.dig("user_id")
      user_id && User.find_by(id: user_id)
    end
  end
end
