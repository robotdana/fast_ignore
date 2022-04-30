# frozen_string_literal: true

class FastIgnore
  module Matchers
    module AllowAnyDir
      class << self
        def squash_id
          :allow_any_dir
        end

        def dir_only?
          true
        end

        def file_only?
          false
        end

        def squash(_)
          self
        end

        def weight
          0
        end

        # :nocov:
        def inspect
          '#<AllowAnyDir>'
        end
        # :nocov:

        def match?(_)
          :allow
        end
      end
    end
  end
end
