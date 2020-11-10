# frozen_string_literal: true

class FastIgnore
  module Matchers
    module Unmatchable
      class << self
        def dir_only?
          false
        end

        def file_only?
          false
        end

        def shebang?
          false
        end

        # :nocov:
        def inspect
          '#<Unmatchable>'
        end
        # :nocov:

        def match?(_)
          false
        end
      end
    end
  end
end
