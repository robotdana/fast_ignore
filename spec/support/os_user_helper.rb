# frozen_string_literal: true

module OSUserHelper
  def os_user
    @os_user ||= if windows?
      ENV.fetch('USERNAME')
    else
      Etc.getpwuid.name
    end
  end
end

RSpec.configure do |config|
  config.include OSUserHelper
  config.extend OSUserHelper
end
