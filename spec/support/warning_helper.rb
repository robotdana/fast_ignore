# frozen_string_literal: true

module WarningHelper
  def silence_warnings
    original_verbose = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = original_verbose
  end
end

RSpec.configure do |config|
  config.include WarningHelper
  config.extend WarningHelper
end
