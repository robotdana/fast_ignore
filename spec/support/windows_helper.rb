# frozen_string_literal: true

module WindowsHelper
  def windows?
    ::RbConfig::CONFIG['host_os'].match?(/mswin|mingw/)
  end
end

RSpec.configure do |config|
  config.include WindowsHelper
  config.extend WindowsHelper
end
