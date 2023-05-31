module InspectHelper
  def default_inspect_value(object)
    Object.instance_method(:inspect).bind(object).call
  end
end

RSpec.configure do |config|
  config.include InspectHelper
end
