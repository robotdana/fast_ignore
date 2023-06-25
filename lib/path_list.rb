# frozen_string_literal: true

require 'strscan'

class PathList
  class Error < StandardError; end

  require_relative 'path_list/autoloader'
  include Autoloader
  include QueryMethods
  extend BuildMethods::ClassMethods
  include BuildMethods

  def initialize
    @matcher = Matchers::Allow
    @use_index = Matchers::Blank
  end

  protected

  def use_index
    matcher # to compress stuff, we're going to anyway

    @use_index
  end

  def matcher
    @compressed ||= begin
      @matcher = @matcher.compress_self
      @use_index = @use_index.compress_self

      true
    end
    @matcher
  end

  def dir_matcher
    @dir_matcher ||= matcher.dir_matcher
  end

  def file_matcher
    @file_matcher ||= matcher.file_matcher
  end
end
