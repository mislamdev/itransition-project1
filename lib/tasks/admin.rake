# Administration tasks.
#
# The demo data of db/seeds.rb is not loaded in the production environment
# (the accounts of the seeds file have public passwords), so a production
# database starts without any account. This task creates the first
# administrator.
#
#   bin/rails "admin:create[admin@example.com,a-strong-password]"
#
# The credentials can also come from the environment, which is what the
# entry point of the container uses:
#
#   ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=a-strong-password bin/rails admin:create
#
# An account that exists already is only promoted to an administrator, its
# password is never changed.
namespace :admin do
  desc "Create an administrator: bin/rails \"admin:create[email,password]\""
  task :create, [:email, :password, :name] => :environment do |_task, args|
    email = args[:email].presence || ENV["ADMIN_EMAIL"].to_s.strip
    password = args[:password].presence || ENV["ADMIN_PASSWORD"].to_s
    name = args[:name].presence || ENV["ADMIN_NAME"].to_s

    if email.blank? || password.blank?
      raise "No credentials given. Use bin/rails \"admin:create[email,password]\" " \
            "or the variables ADMIN_EMAIL and ADMIN_PASSWORD."
    end

    user = User.find_or_initialize_by(email: email)

    if user.persisted?
      user.admin = true
      user.save!
      puts "The account #{email} is an administrator now."
    else
      user.name = name.presence || "Administrator"
      user.password = password
      user.admin = true
      user.save!
      puts "The administrator #{email} was created."
    end
  end
end
