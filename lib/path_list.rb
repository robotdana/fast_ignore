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
    @dir_matcher = nil
    @file_matcher = nil
  end

  protected

  attr_reader :matcher

  private

  def dir_matcher
    @dir_matcher ||= @matcher.dir_matcher
  end

  def file_matcher
    @file_matcher ||= @matcher.file_matcher
  end
end
