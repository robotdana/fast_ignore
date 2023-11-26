# frozen_string_literal: true

module StubENVHelper
  def stub_env_original
    @stub_env_original ||= allow(::ENV).to receive(:[]).at_least(:once).and_call_original
  end

  def stub_env(**values)
    stub_blank_global_config
    clear_pattern_cache_now_and_after

    stub_env_original
    values.each do |key, value|
      allow(::ENV).to receive(:[]).with(key.to_s).at_least(:once).and_return(value)
    end

    stubbed_env.merge!(values)
  end

  def stubbed_env
    @stubbed_env ||= {}
  end
end

RSpec.configure do |config|
  config.include StubENVHelper
end
