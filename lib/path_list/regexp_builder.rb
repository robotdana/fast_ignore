# frozen_string_literal: true

class PathList
  class RegexpBuilder # rubocop:disable Metrics/ClassLength
    include Autoloader

    def self.union(builders)
      new(Merge.merge(builders.map(&:parts)))
    end

    def self.new_from_path(path, tail = { end_anchor: nil })
      rb = new
      rb.append_part(:start_anchor)
      path.delete_prefix('/').split('/').each do |part|
        rb.append_part(:dir)
        rb.append_part(part)
      end
      rb.append_tail_n(tail)
      rb
    end

    attr_reader :parts

    def initialize(parts = {})
      @parts = parts
    end

    def empty?
      @parts.empty?
    end

    def exact_string? # rubocop:disable Metrics/MethodLength
      tail_part, tail = @parts.first

      return false unless tail_part == :start_anchor

      while (tail_part, next_tail = tail.first) && !next_tail.nil?
        return false if tail.length > 1
        return false unless tail_part.is_a?(String) ||
          tail_part == :dir ||
          tail_part == :end_anchor ||
          tail_part.nil?

        tail = next_tail
      end
      return false unless tail_part == :end_anchor

      true
    end

    def start_with?(value)
      @parts.key?(value)
    end

    def dup
      out = super

      @parts = @parts.dup
      @tail = @tail.dup if @tail

      out
    end

    def end_with?(part)
      @tail.key?(part)
    end

    def to_s
      Builder.to_literal_s(@parts)
    end

    def to_regexp
      Builder.to_regexp(@parts)
    end

    def compressed?
      @compressed
    end

    def compress
      @compressed ||= begin
        @parts = Compress.compress(@parts)

        true
      end

      self
    end

    def ancestors # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      new_builder = self.class.new

      last_dir_tail = prev_prev_tail_part = prev_tail_part = nil
      tail_part = next_tail = nil # rubocop:disable Lint/UselessAssignment
      tail = @parts

      while (tail_part, next_tail = tail.first) && !next_tail.nil?
        tail = next_tail
        if tail_part == :any_dir
          last_dir_tail = nil
          break
        end

        new_builder.append_part(tail_part)
        if tail_part == :dir && prev_tail_part != :start_anchor
          new_builder.append_forked_part(:end_anchor)
          last_dir_tail = new_builder.tail if tail_part == :dir
        end
        new_builder.append_forked_part(:end_anchor) if prev_prev_tail_part == :start_anchor
        prev_prev_tail_part = prev_tail_part
        prev_tail_part = tail_part
      end
      last_dir_tail&.replace(end_anchor: nil)

      new_builder
    end

    def replace_tail(part)
      @tail || find_tail
      @tail.replace(part => nil)
    end

    def append_forked_part(part)
      @tail || find_tail
      @tail.merge!(part => nil)
    end

    def find_tail(parts = @parts)
      tail = parts
      value = parts # rubocop:disable Lint/UselessAssignment
      tail = value while (key, value = tail.first) && !value.nil?

      @tail = tail
      @tail_part = key
    end

    def append_tail_n(new_tail)
      append_tail_1(new_tail)
      # we need to find the tail of the tail
      find_tail(new_tail)
    end

    def append_tail_1(new_tail)
      if @tail_part
        @tail[@tail_part] = new_tail
      elsif @parts.empty?
        @parts = new_tail
      else

        tail = @parts
        value = @parts # rubocop:disable Lint/UselessAssignment
        tail = value while (key, value = tail.first) && !value.nil?
        tail[key] = new_tail
      end
    end

    def forget_tail
      @tail = nil
      @tail_part = nil
    end

    def append_part(part)
      new_tail = { part => nil }
      append_tail_1(new_tail)
      @tail = new_tail
      @tail_part = part
    end

    def append_string(value)
      return unless value

      if @tail_part.is_a?(String)
        @tail_part = "#{@tail_part}#{value}"
        @tail.replace(@tail_part => nil)
      else
        append_part(value)
      end
    end

    protected

    attr_reader :tail
  end
end
