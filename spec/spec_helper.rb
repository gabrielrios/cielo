require 'cielo'
require 'vcr'
require 'rspec/xsd'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.preserve_exact_body_bytes { true }
end

RSpec.configure do |config|
    config.include RSpec::XSD
end