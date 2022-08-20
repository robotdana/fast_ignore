# frozen_string_literal: true

class FastIgnore
  module Matchers
    module AllowAnyParent
      class << self
        def dir_only?
          true
        end

        def file_only?
          false
        end

        def squash(_)
          self
        end

        def implicit?
          true
        end

        def squashable_with?(other)
          other == self
        end

        def weight
          0
        end

        def removable?
          false
        end

        # :nocov:
        def inspect
          '#<AllowAnyParent>'
        end
        # :nocov:

        def match(candidate)
          :allow if candidate.parent?
        end
      end
    end
  end
end
