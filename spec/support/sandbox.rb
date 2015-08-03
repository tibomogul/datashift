


class Sandbox

  def self.rails_sandbox_path
    File.expand_path('../../rails_sandbox', __FILE__)
  end


  def self.gen_rails_sandbox( force = false)

    sandbox = rails_sandbox_path

    if(force == true && File.exist?(sandbox))
      FileUtils::rm_rf(sandbox)
    end

    puts "RSPEC - checking for Rails sandbox [#{sandbox}]"

    unless(File.exist?(sandbox))

      sandbox_exe_path =  File.expand_path( "#{sandbox}/.." )

      puts "Creating new Rails sandbox in : #{sandbox_exe_path}"

      run_in( sandbox_exe_path ) do |path|

        name = File.basename(rails_sandbox_path)

        system('rails new ' + name)

        puts "Copying over models :", Dir.glob(File.join(fixtures_path, 'models', '*.rb')).inspect

        FileUtils::cp_r( Dir.glob(File.join(fixtures_path, 'models', '*.rb')), File.join(name, 'app/models'))

        migrations = File.expand_path(File.join(fixtures_path, 'db', 'migrate'), __FILE__)

        FileUtils::cp_r( migrations, File.join(rails_sandbox_path, 'db'))

        FileUtils::cp_r( File.join(fixtures_path, 'sandbox_example.thor'), rails_sandbox_path)
      end


      run_in(rails_sandbox_path) do

        add_gem 'datashift', path: rspec_datashift_root
        add_gem 'awesome_print', github: 'michaeldv/awesome_print', branch: 'master'
        add_gem 'active_scaffold'

        system("cat #{File.join(rails_sandbox_path, 'Gemfile')}")
      end


      run_in(rails_sandbox_path) do


        puts "Running bundle install for [#{File.join(rails_sandbox_path, 'Gemfile')}]"

        Bundler.with_clean_env do
          system("bundle install  --gemfile #{File.join(rails_sandbox_path, 'Gemfile')}")
        end

        puts "Creating and migrating DB"

        system('bundle exec rake db:create')

        puts "Running db:migrate"

        system('RAILS_ENV=development bundle exec rake db:migrate')
        system('RAILS_ENV=test bundle exec rake db:migrate')

        threads = []

        Dir.glob(File.join(fixtures_path, 'models', '*.rb')).each do |m|
          threads << Thread.new { system("RAILS_ENV=development bundle exec rails g active_scaffold #{File.basename(m, '.*')}") }

          threads << Thread.new { system("RAILS_ENV=development bundle exec rails g resource_route #{File.basename(m, '.*')}") }
        end

        threads.each { |thr| thr.join }

        system('bundle install')
      end
    else
      puts "RSPEC - found and using existing Rails sandbox [#{sandbox}]"
    end
    return sandbox
  end


  def self.add_gem(name, gem_options={})

    puts "Append Gemfile with #{name}"
    parts = ["'#{name}'"]
    parts << ["'#{gem_options.delete(:version)}'"] if gem_options[:version]
    gem_options.each { |key, value| parts << "#{key}: '#{value}'" }

    File.open('Gemfile', 'ab') do |file|
      file.write( "\ngem #{parts.join(', ')}")
    end

  end


end