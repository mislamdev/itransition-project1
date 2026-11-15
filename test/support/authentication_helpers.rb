# frozen_string_literal: true

# Helpers shared by the authentication and administration tests.
module AuthenticationHelpers
  # A password long enough for every validation of the User model.
  DEFAULT_PASSWORD = "correct horse battery staple"

  # Creates a user with a known password.
  #
  # The email address is generated when it is not given, so that the tests
  # never depend on each other.
  def create_user(email: nil, password: DEFAULT_PASSWORD, **attributes)
    email ||= "user-#{SecureRandom.hex(8)}@example.test"
    name = attributes.delete(:name) || "Test User"

    User.create!(
      email: email,
      name: name,
      password: password,
      password_confirmation: password,
      **attributes
    )
  end

  # Creates an administrator.
  def create_admin(**attributes)
    create_user(admin: true, **attributes)
  end

  # Signs a user in through the sign in form.
  def sign_in_as(user, password: DEFAULT_PASSWORD)
    post sign_in_path, params: { email: user.email, password: password }
    user
  end

  # The id of the user behind the session of the last request, or nil.
  def session_user_id
    request.session[:user_id]
  end

  def signed_in?
    session_user_id.present?
  end

  # The path of a page that may only be reached by a signed in user.
  # The admin user list is used because it is the only page of the
  # application that is protected and that every account may ask for.
  def protected_path
    admin_users_path
  end
end
