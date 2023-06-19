# frozen_string_literal: true

class PathList
  class RelativeCandidate
    attr_reader :path

    def initialize(candidate, relative_path, relative_to)
      @candidate = candidate
      @path = relative_path
    end

    # TODO, link back to parent
    def relative_to(dir)
      @candidate.relative_to(@relative_to + dir)
    end

    def parent
      return @parent if defined?(@parent)

      @parent = @candidate.parent&.relative_to(@relative_to)
    end

    def full_path
      @candidate.full_path
    end

    def path_list
      @candidate.path_list
    end

    def directory?
      @candidate.directory?
    end

    def exists?
      @candidate.exists?
    end

    def filename
      @candidate.filename
    end

    def first_line # rubocop:disable Metrics/MethodLength
      @candidate.first_line
    end

    alias_method :original_inspect, :inspect # leftovers:keep

    def inspect
      "#<#{self.class} #{@path} @relative_to=#{@relative_to}>"
    end
  end
end
