# frozen_string_literal: true

class PathList
  module Matchers
    AllowAnyDir = MatchIfDir.new(Allow)
  end
end
