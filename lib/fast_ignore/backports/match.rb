# frozen_string_literal: true

# This is a backport of ruby 2.4's match? method
class FastIgnore
  module Backports
    module Match
      refine ::String do
        alias_method :match?, :match
      end

      refine ::Regexp do
        alias_method :match?, :match
      end
    end
  end
end
