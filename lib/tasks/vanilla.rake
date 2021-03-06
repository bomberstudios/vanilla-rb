$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))
require 'vanilla'

namespace :vanilla do
  desc "Open an irb session preloaded with this library"
  task :console do
    sh "irb -Ilib -rubygems -rvanilla -rvanilla/console"
  end

  task :clean do
    # TODO: get the database name from Soup
    FileUtils.rm "soup.db" if File.exist?("soup.db")
  end

  task :load_snips do
    app = Vanilla::App.new(ENV['VANILLA_CONFIG'])
    print "Preparing soup... "
    Dynasnip.all.each { |ds| app.soup << ds.snip_attributes }
    Dir[File.join(File.dirname(__FILE__), '..', 'vanilla', 'snips', '*.rb')].each do |f|
      load f
    end
    puts "the soup is simmering."
  end

  desc 'Resets the soup to contain the base snips only. Dangerous!'
  task :reset => [:clean, :load_snips]

  namespace :upgrade do
    desc 'Upgrade the dynasnips'
    task :dynasnips do
      app = Vanilla::App.new(ENV['VANILLA_CONFIG'])
      Dynasnip.all.each do |dynasnip|
        print "Upgrading #{dynasnip.snip_name}... "
        # TODO: our confused Soup interface might return an array.
        snip = app.soup[dynasnip.snip_name]
        if snip.empty? || snip.nil?
          # it's a new dyna
          app.soup << dynasnip.snip_attributes
          puts "(new)"
        elsif snip.created_at == snip.updated_at
          # it's not been changed, let's upgrade
          snip.destroy
          app.soup << dynasnip.snip_attributes
          puts "(unedited)"
        else
          # the dyna exists and has been changed
          dynasnip.snip_attributes.each do |name, value|
            unless (existing_value = snip.get_value(name)) == value
              puts "Conflict in attribute '#{name}':"
              puts "> Your soup: '#{existing_value}'"
              puts ">  New soup: '#{value}"
              print "Upgrade? [Y/n]: "
              upgrade_value = ["Y", "y", ""].include? STDIN.gets.chomp.strip
              snip.set_value(name, value) if upgrade_value
            end
          end
          snip.save
        end
      end
    end
  end

  desc 'Upgrade dynasnips and system snips'
  task :upgrade => ["upgrade:dynasnips"]

  desc 'Add a user (or change an existing password)'
  task :add_user do
    require 'md5'
    puts "Adding a new user"
    # config_file = ENV['VANILLA_CONFIG'] || 'config.yml'
    # config_file = YAML.load(File.open(config_file)) rescue {}
    app = Vanilla::App.new(ENV['VANILLA_CONFIG'])
    print "Username: "
    username = STDIN.gets.chomp.strip
    print "Password: "
    password = STDIN.gets.chomp.strip
    print "Confirm password: "
    confirm_password = STDIN.gets.chomp.strip
    if password != confirm_password
      raise "Passwords don't match!"
    else
      app.config[:credentials] ||= {}
      app.config[:credentials][username] = MD5.md5(password).to_s
      app.config.save!
      puts "User '#{username}' added."
    end
  end

  desc 'Generate file containing secret for cookie-based session storage'
  task :generate_secret do
    print "Generating cookie secret... "
    # Adapted from old rails secret generator.
    require 'openssl'
    if !File.exist?("/dev/urandom")
      # OpenSSL transparently seeds the random number generator with
      # data from /dev/urandom. On platforms where that is not
      # available, such as Windows, we have to provide OpenSSL with
      # our own seed. Unfortunately there's no way to provide a
      # secure seed without OS support, so we'll have to do with
      # rand() and Time.now.usec().
      OpenSSL::Random.seed(rand(0).to_s + Time.now.usec.to_s)
    end
    data = OpenSSL::BN.rand(2048, -1, false).to_s
    secret = OpenSSL::Digest::SHA1.new(data).hexdigest
    app = Vanilla::App.new(ENV['VANILLA_CONFIG'])
    app.config[:secret] = secret
    app.config.save!
    puts "done; cookies are twice baked. BIS-CUIT!"
  end

  desc 'Prepare standard files to run Vanilla'
  task :prepare_files do
    cp File.expand_path(File.join(File.dirname(__FILE__), *%w[.. .. config.ru])), 'config.ru'
    cp File.expand_path(File.join(File.dirname(__FILE__), *%w[.. .. config.example.yml])), 'config.yml'
    cp File.expand_path(File.join(File.dirname(__FILE__), *%w[.. .. README_FOR_APP])), 'README'
    cp_r File.expand_path(File.join(File.dirname(__FILE__), *%w[.. .. public])), 'public'
    mkdir 'tmp'
    File.open("Rakefile", "w") do |f|
      rakefile =<<-EOF
require 'vanilla'
load 'tasks/vanilla.rake'

# Add any other tasks here.
EOF
      f.write rakefile.strip
    end
  end


  desc 'Prepare a new vanilla.rb installation'
  task :setup do
    puts <<-EOM
____________________.c( Vanilla.rb )o._____________________

Congratulations! You have elected to try out the weirdest web 
thing ever. Lets get started.

EOM
  Rake::Task['vanilla:prepare_files'].invoke
  Rake::Task['vanilla:generate_secret'].invoke
  Rake::Task['vanilla:load_snips'].invoke

  puts <<-EOM

___________________.c( You Are Ready )o.___________________

#{File.readlines('README')[0,16].join}
  EOM
  end
end
