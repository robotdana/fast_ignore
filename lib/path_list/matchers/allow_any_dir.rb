# frozen_string_literal: true

class PathList
  module Matchers
    AllowAnyDir = MatchIfDir.build(Allow)
  end
end
