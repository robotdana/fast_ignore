# frozen_string_literal: true

class PathList
  class Builder
    Autoloader.autoload(self)

    def initialize(rule, polarity, root)
      @rule = rule
      @polarity = polarity
      @root = root
    end
  end
end
