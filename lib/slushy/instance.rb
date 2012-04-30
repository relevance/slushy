require 'timeout'

class Slushy::Instance
  attr_reader :connection, :instance_id

  def self.launch(connection, config)
    server = connection.servers.create(config)
    server.wait_for { ready? }
    new(connection, server.id)
  end

  def initialize(connection, instance_id)
    @connection = connection
    @instance_id = instance_id
  end

  def server
    @server ||= @connection.servers.get(instance_id)
  end

  def ssh(*args)
    server.ssh(*args)
  end

  def scp(*args)
    server.scp(*args)
  end

  def dns_name(*args)
    server.dns_name(*args)
  end

  def snapshot(name, description)
    response = connection.create_image(instance_id, name, description)
    image_id = response.body["imageId"]
    image = connection.images.get(image_id)
    image.wait_for { state == "available" }
    image_id
  end

  def terminate
    server.destroy
    server.wait_for { state == "terminated" }
  end

  def stop
    server.stop
    server.wait_for { state == "stopped" }
  end

  def wait_for_connectivity
    puts "Waiting for ssh connectivity..."
    retry_block(5, [Errno::ECONNREFUSED, Timeout::Error], "Connecting to Amazon refused") do
      sleep 10
      Timeout.timeout(60) { ssh('ls') }
    end
    puts "Server up and listening for SSH!"
  end

  def run_command(command)
    jobs = ssh(command)
    jobs_succeeded?(jobs)
  end

  def run_command!(command)
    raise Slushy::Error.new("Failed running '#{command}'") unless run_command(command)
  end

  def apt_installs
    retry_block(5, [Slushy::Error], "Command 'apt-get' failed") do
      puts "Updating apt cache..."
      run_command!('sudo apt-get update')
      puts "Installing ruby..."
      run_command!('sudo apt-get -y install ruby')
      puts "Installing rubygems..."
      run_command!('sudo apt-get -y install rubygems1.8')
    end
  end

  def bootstrap
    wait_for_connectivity
    apt_installs
    puts "Installing chef..."
    run_command!('sudo gem install chef --no-ri --no-rdoc --version 0.10.8')
  end

  def converge(cookbooks_path) # TODO: find the standard Chef term for this
    puts "Copying chef resources from provision directory..."
    cookbooks_path = "#{cookbooks_path}/" unless cookbooks_path.to_s.end_with?('/')
    scp(cookbooks_path, '/tmp/chef-solo', :recursive => true)
    puts "Converging server, this may take a while (10-20 minutes)"
    run_command!('cd /tmp/chef-solo && sudo /var/lib/gems/1.8/bin/chef-solo -c solo.rb -j dna.json')
  end

  protected

  def retry_block(times, errors, failure)
    succeeded = false
    attempts = 0
    last_error = nil
    until succeeded || attempts > times-1
      begin
        retval = yield
        succeeded = true
      rescue *errors => e
        attempts +=1
        puts "#{failure}. Attempting retry #{attempts}..."
        last_error = e
      end
    end
    raise Slushy::Error.new(failure) unless succeeded
    retval
  end

  def jobs_succeeded?(jobs)
    return true if jobs.all? { |job| job.status == 0 }
    jobs.each do |job|
      puts "----------------------"
      puts "Command '#{job.command}'"
      puts "STDOUT: #{job.stdout}"
      puts "STDERR: #{job.stderr}"
      puts "----------------------"
    end
    false
  end
end
