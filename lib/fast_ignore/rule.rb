# frozen_string_literal: true

require 'helix_runtime'
require_relative 'native'

class FastIgnore
  class Rule
    def initialize(rule, dir_only, negation)
      @native = FastIgnoreRule.new(rule, dir_only, negation)
    end

    def negation?
      @native.negation
    end

    def dir_only?
      @native.dir_only
    end

    def match?(path)
      @native.fnmatch(path)
    end
  end
end
