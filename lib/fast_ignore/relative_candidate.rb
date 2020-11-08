# frozen-string-literal: true

class FastIgnore
  class RelativeCandidate
    attr_reader :relative_path

    def initialize(relative_path, root_candidate)
      @relative_path = relative_path
      @root_candidate = root_candidate
    end

    def directory?
      @root_candidate.directory?
    end

    def filename
      @root_candidate.filename
    end

    def first_line
      @root_candidate.first_line
    end
  end
end
