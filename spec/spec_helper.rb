require 'rspec/autorun'
require 'slushy'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.expand_path("support/*.rb", File.dirname(__FILE__))].each {|f| require f}

RSpec.configure do |config|
  config.filter_run :focused => true
  config.filter_run_excluding :disabled => true
  config.run_all_when_everything_filtered = true

  config.alias_example_to :fit, :focused => true
  config.alias_example_to :xit, :disabled => true
  config.alias_example_to :they
end
