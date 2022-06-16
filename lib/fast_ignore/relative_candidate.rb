# frozen-string-literal: true

class FastIgnore
  class RelativeCandidate
    attr_reader :path

    def initialize(relative_path, root_candidate)
      @path = relative_path
      @root_candidate = root_candidate
    end

    def filename
      @root_candidate.filename
    end

    def first_line
      @root_candidate.first_line
    end

    def directory?
      @root_candidate.directory?
    end
  end
end
