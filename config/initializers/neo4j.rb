Snpr::Application.config.neo4j.tap do |config|
  config.session_type = :server_db 
  config.session_path = ENV['NEO4J_URL']
  config.session_options = {
    basic_auth: {
      username: ENV['NEO4J_USERNAME'],
      password: ENV['NEO4J_PASSWORD'],
    }
  } 
end
