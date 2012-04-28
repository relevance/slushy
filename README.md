## Description

Giving Chef a hand in the provisional kitchen, [aussie style](http://www.mrl.nott.ac.uk/~mbf/paula/slushy.htm).
Assumes Fog's API for connecting to and creating instances.

## Usage

Provision and converge an instance:

```ruby
connection = Fog::Compute.new :provider => 'AWS', :aws_access_key => 'KEY',
  :aws_secret_access_key => 'SECRET'
# Second arg is a hash passed to Fog::Compute::AWS::Servers.create
instance = Slushy::Instance.launch connection, :flavor_id => 'm1.large', :more => :keys
instance.bootstrap
# Point at directory containing Chef cookbooks
instance.converge Rails.root.join('provision')
```

## TODO

* Speed up slow Instance.launch tests caused by Fog's mocking
* Add SystemTimer for a working 1.8.7 timeout
* Support providers other than AWS
* Support OSes other ubuntu
* Don't hardcode path to chef, caused by ubuntu installing weirdness
* Fix Instance#wait_for_connectivity occasionally hanging
