# frozen_string_literal: true

class FastIgnore
  module Backports
    module_function

    def ruby_version_less_than?(major, minor)
      ruby_major, ruby_minor = RUBY_VERSION.split('.', 2)

      return true if major > ruby_major.to_i
      return true if minor > ruby_minor.to_i

      false
    end
  end
end
