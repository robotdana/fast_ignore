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

        def weight
          0
        end

        def squashable_with?(_)
          false
        end

        # it's not removable
        # but it is squashable with anything
        def removable?
          false
        end

        def implicit?
          true
        end

        # :nocov:
        def inspect
          '#<Unmatchable>'
        end
        # :nocov:

        def match(_)
          false
        end
      end
    end
  end
end
