require 'spec_helper'
require 'fog'
require 'pathname'

describe Slushy::Instance do
  def mock_job(options={})
    mock({:command => 'foo', :stdout => '', :stderr => '', :status => 0}.merge(options))
  end

  before(:all) { Fog.mock! }

  let(:connection)  { Fog::Compute.new(:provider => 'AWS', :aws_access_key_id => "foo", :aws_secret_access_key => "bar") }
  let(:config)      { {:flavor_id => 'm1.large', :image_id => 'ami-123456', :groups => ['default']} }
  let(:server)      { connection.servers.create(config) }
  let(:instance_id) { server.id }
  let(:instance)    { Slushy::Instance.new(connection, instance_id) }

  describe ".launch" do
    it "launches a new instance" do
      lambda { described_class.launch(connection, config) }.should change { connection.servers.size }.by(1)
    end

    it "raises if wait_for fails" do
      servers = stub(:create => server)
      connection.stub(:servers).and_return(servers)
      server.stub(:wait_for).and_return(false)
      lambda { described_class.launch(connection, config) }.should raise_error(Slushy::TimeoutError)
    end

    it "returns the instance object" do
      described_class.launch(connection, config).should be_a Slushy::Instance
    end

    describe "the new instance" do
      subject { described_class.launch(connection, config).server }

      its(:flavor_id) { should == 'm1.large' }
      its(:image_id)  { should == 'ami-123456' }
      its(:groups)    { should include('default') }
    end
  end

  describe "#server" do
    it "retrieves the server from the connection based on instance_id" do
      servers = stub(:create => server)
      connection.stub(:servers).and_return(servers)
      servers.should_receive(:get).with(server.id).and_return(server)
      instance.server.should == server
    end
  end

  describe "#snapshot" do
    let!(:image)   { connection.images.new(Fog::AWS::Mock.image) }
    let(:images)   { stub(:get => image) }
    let(:response) { stub(:body => {"imageId" => :some_ami_id}) }

    before { connection.stub(:images).and_return(images) }

    it "creates a new AMI from the given instance and returns the AMI id string" do
      connection.should_receive(:create_image).with(instance_id, :some_name, :some_description).and_return(response)
      instance.snapshot(:some_name, :some_description).should == :some_ami_id
    end

    it "does NOT return until image creation is complete" do
      connection.stub(:create_image).and_return(response)
      images.should_receive(:get).with(:some_ami_id).and_return(image)
      image.should_receive(:ready?).ordered.and_return(false)
      image.should_receive(:ready?).ordered.and_return(true)
      instance.snapshot(:some_name, :some_description)
    end

    it "raises if wait_for fails" do
      connection.stub(:create_image).and_return(response)
      images.should_receive(:get).with(:some_ami_id).and_return(image)
      image.stub(:wait_for).and_return(false)
      lambda { instance.snapshot(:some_name, :some_description) }.should raise_error(Slushy::TimeoutError)
    end
  end

  describe "#terminate" do
    it "terminates the given instance" do
      instance.stub(:server).and_return(server)
      server.should_receive(:destroy)
      server.should_receive(:state).ordered.and_return("running")
      server.should_receive(:state).ordered.and_return("terminated")
      instance.terminate
    end

    it "raises if wait_for fails" do
      instance.stub(:server).and_return(server)
      server.stub(:destroy)
      server.stub(:wait_for).and_return(false)
      lambda { instance.terminate }.should raise_error(Slushy::TimeoutError)
    end
  end

  describe "#stop" do
    it "stops the given instance" do
      instance.stub(:server).and_return(server)
      server.should_receive(:stop)
      server.should_receive(:state).ordered.and_return("running")
      server.should_receive(:state).ordered.and_return("stopped")
      instance.stop
    end

    it "raises if wait_for fails" do
      instance.stub(:server).and_return(server)
      server.stub(:stop)
      server.stub(:wait_for).and_return(false)
      lambda { instance.stop }.should raise_error(Slushy::TimeoutError)
    end
  end

  describe '#wait_for_connectivity' do
    before { instance.stub(:server).and_return(server) }

    it 'retries if the first attempt fails' do
      instance.should_receive(:ssh).ordered.and_raise(Errno::ECONNREFUSED)
      instance.should_receive(:ssh).ordered.and_return([mock_job])
      instance.should_receive(:sleep).twice.with(10).and_return(10)
      expect do
        capture_stdout { instance.wait_for_connectivity }
      end.to_not raise_error
    end

    it 'prints a message for each retry attempt' do
      instance.should_receive(:ssh).ordered.exactly(3).times.and_raise(Errno::ECONNREFUSED)
      instance.should_receive(:ssh).ordered.and_return([mock_job])
      instance.stub(:sleep).and_return(10)
      stdout = capture_stdout { instance.wait_for_connectivity }
      stdout.should include 'Attempting retry 1...'
      stdout.should include 'Attempting retry 2...'
      stdout.should include 'Attempting retry 3...'
    end

    it 'retries up to five times, then fails' do
      instance.should_receive(:ssh).exactly(5).times.and_raise(Errno::ECONNREFUSED)
      instance.stub(:sleep).and_return(10)
      expect do
        capture_stdout { instance.wait_for_connectivity }
      end.to raise_error Slushy::TimeoutError
    end
  end

  describe '#run_command!' do
    it "fails fast if a command fails" do
      job = mock_job(:status => 1, :stderr => 'FAIL WHALE')
      instance.stub(:ssh).with("ls").and_return([job])
      capture_stdout do
        expect do
          instance.run_command!("ls")
        end.to raise_error Slushy::CommandFailedError
      end.should =~ /STDERR: FAIL WHALE/
    end
  end

  describe '#apt_installs' do
    it 'retries if the first attempt fails' do
      instance.should_receive(:ssh).ordered.with('sudo apt-get update').and_return([mock_job])
      instance.should_receive(:ssh).ordered.with('sudo apt-get -y install ruby').and_return([mock_job(:status => 1)])
      instance.should_receive(:ssh).ordered.with('sudo apt-get update').and_return([mock_job])
      instance.should_receive(:ssh).ordered.with('sudo apt-get -y install ruby').and_return([mock_job])
      instance.should_receive(:ssh).ordered.with('sudo apt-get -y install rubygems1.8').and_return([mock_job])
      expect do
        capture_stdout { instance.apt_installs }
      end.to_not raise_error
    end

    it 'retries up to five times, then fails' do
      instance.should_receive(:ssh).exactly(5).times.with('sudo apt-get update').and_return([mock_job(:status => 1)])
      expect do
        capture_stdout { instance.apt_installs }
      end.to raise_error Slushy::CommandFailedError
    end
  end

  describe "#bootstrap" do
    it "installs prerequisites on the given instance" do
      instance.should_receive(:wait_for_connectivity).ordered
      instance.should_receive(:run_command).ordered.with("sudo apt-get update").and_return(true)
      instance.should_receive(:run_command).ordered.with("sudo apt-get -y install ruby").and_return(true)
      instance.should_receive(:run_command).ordered.with("sudo apt-get -y install rubygems1.8").and_return(true)
      instance.should_receive(:run_command).ordered.with("sudo gem install chef --no-ri --no-rdoc --version 0.10.8").and_return(true)
      capture_stdout { instance.bootstrap }
    end
  end

  describe "#converge" do
    it "converges the given instance" do
      instance.should_receive(:run_command!).ordered.with("sudo rm -rf /tmp/chef-solo")
      instance.should_receive(:scp).ordered.with('some_path/', "/tmp/chef-solo", :recursive => true).and_return(true)
      instance.should_receive(:run_command!).ordered.with(%Q{cd /tmp/chef-solo && sudo sh -c "PATH=/var/lib/gems/1.8/bin:/usr/local/bin:$PATH chef-solo -c solo.rb -j dna.json"}).and_return(true)
      capture_stdout { instance.converge(Pathname.new('some_path')) }
    end
  end
end
