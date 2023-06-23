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
  end

  def dup
    d = super
    d.matcher = matcher
    d
  end

  protected

  attr_accessor :matcher

  def dir_matcher
    @dir_matcher ||= matcher.dir_matcher
  end

  def file_matcher
    @file_matcher ||= matcher.file_matcher
  end
end
