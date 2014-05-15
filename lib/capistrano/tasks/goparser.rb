namespace :go_parser do
  desc 'Compiles go_parser'
  task :compile do
    rake("go_worker:build")
  end
end
