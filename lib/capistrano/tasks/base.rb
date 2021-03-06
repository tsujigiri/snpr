namespace :deploy do
  task :set_symlinks do
    ln("#{shared_path}/config/app_config.yml", "#{release_path}/config/app_config.yml")
    ln("#{shared_path}/config/database.yml", "#{release_path}/config/database.yml")
    ln("#{shared_path}/config/secret_token", "#{release_path}/secret_token")
    ln("#{shared_path}/config/mail_username.txt", "#{release_path}/mail_username.txt")
    ln("#{shared_path}/config/mail_password.txt", "#{release_path}/mail_password.txt")
    mkdir("#{release_path}/solr/pids")
    ln("#{shared_path}/pids", "#{release_path}/solr/pids/production")
    mkdir("#{shared_path}/assets")
    ln("#{shared_path}/assets", "#{release_path}/public/assets")
  end
  after "deploy:create_shared_dirs", "deploy:set_symlinks"

  task :create_shared_dirs do
    mkdir("#{shared_path}/config")
  end
  after "deploy:update_code", "deploy:create_shared_dirs"
end
