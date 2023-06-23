# frozen_string_literal: true

class PathList
  class RegexpBuilder
    # include ComparableInstance
    include Autoloader

    def self.union(builders)
      new(Merge.merge(builders.map(&:parts)))
    end

    def self.new_from_path(path, tail = [:end_anchor])
      new(
        [:start_anchor] + path
          .delete_prefix('/')
          .split('/')
          .flat_map { |part| [:dir, Regexp.escape(part)] } + tail
      ).compress
    end

    attr_reader :parts

    def initialize(parts = [])
      @parts = parts
      @unanchorable = false
      @character_class = nil
    end

    def start=(value)
      @parts[0] = value
    end

    def [](index)
      @parts[index]
    end

    def []=(index, value)
      @parts[index] = value
    end

    def empty?
      @parts.empty?
    end

    def start_with?(value)
      @parts[0] == value
    end

    def end=(value)
      @parts[-1] = value
    end

    def dup
      out = super

      @parts = @parts.dup

      out
    end

    def end_with?(part)
      @parts[-1] == part
    end

    def to_s(builder = Builder)
      builder.to_s(@parts)
    end

    def to_regexp(builder = Builder)
      builder.to_regexp(@parts)
    end

    def compress
      @parts = Compress.compress(@parts)

      self
    end

    def ancestors # rubocop:disable Metrics/AbcSize
      prev_rule = []
      rules = [self.class.new([:start_anchor, :dir, :end_anchor])]

      parts = @parts

      any_dir_index = parts.index(:any) || parts.index(:any_dir)
      parts = parts[0, any_dir_index] + [:any, :dir] if any_dir_index

      parts.slice_before(:dir).to_a[0...-1].each do |chunk|
        prev_rule.concat(chunk)
        (rules << self.class.new(prev_rule + [:end_anchor])) unless prev_rule == [:start_anchor]
      end

      self.class.union(rules.each(&:compress))
    end

    def append_part(value)
      @parts << value
    end

    def append_string(value)
      return unless value

      append_unescaped(::Regexp.escape(value))
    end

    def append_unescaped(value)
      return unless value

      if @parts[-1].is_a?(String)
        @parts[-1] << value
      else
        @parts << value
      end
    end
  end
end
