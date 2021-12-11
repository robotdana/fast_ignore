# frozen_string_literal: true

module StubENVHelper
  def stub_env_original
    @stub_env_original ||= begin
      allow(::ENV).to receive(:[]).at_least(:once).and_call_original
    end
  end

  def stub_env(**values)
    stub_env_original
    values.each do |key, value|
      allow(::ENV).to receive(:[]).with(key.to_s).at_least(:once).and_return(value)
    end
  end
end

RSpec.configure do |config|
  config.include StubENVHelper
end
