# frozen_string_literal: true

class FastIgnore
  class UnmatchableRule
    def self.squash(rules)
      rules.first
    end

    def squashable_type
      5
    end

    def dir_only?
      false
    end

    def anchored?
      true
    end

    def file_only?
      false
    end

    def shebang
      nil
    end

    # :nocov:
    def inspect
      '#<UnmatchableRule>'
    end
    # :nocov:

    def match?(_, _, _, _)
      false
    end
  end
end
