module Authlogic
  module TestHelper
    def create_user_session(user)
      post user_session_path, user_session: { email: user.email, password: 'jeheim' }
    end
  end
end

RSpec.configure do |config|
  config.include Authlogic::TestHelper, type: :request
  config.include Authlogic::TestHelper, type: :feature
end
