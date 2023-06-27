# frozen_string_literal: true

class PathList
  class Builder
    include Autoloader

    def initialize(rule, polarity, root)
      @rule = rule
      @polarity = polarity
      @root = root
    end
  end
end
