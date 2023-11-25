# frozen_string_literal: true

module ClearCacheHelper
  def clear_pattern_cache_now_and_after
    PathList::Cache.clear
    @clear_pattern_cache_after = true
  end
end

RSpec.configure do |config|
  config.include ClearCacheHelper
end
