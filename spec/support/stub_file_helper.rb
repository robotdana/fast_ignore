# frozen_string_literal: true

module StubFileHelper
  def stub_file_original
    @stub_file_original ||= stub_file_attributes.each_key do |method|
      allow(::File).to receive(method).at_least(:once).and_call_original
    end
  end

  def stub_file(*lines, path:)
    stub_blank_global_config
    clear_pattern_cache_now_and_after

    stub_file_original
    path = ::File.expand_path(path)

    stub_file_attributes(lines.join("\n")).each do |method, value|
      stub = allow(::File).to receive(method).with(path)
      value.is_a?(Exception) ? stub.and_raise(value) : stub.at_least(:once) { value.dup }
    end

    path
  end

  def stub_file_attributes(content = nil)
    exist = !content.nil?

    {
      readable?: exist,
      exist?: exist,
      read: content || Errno::ENOENT,
      readlines: content&.split("\n").freeze || Errno::ENOENT
    }
  end
end

RSpec.configure do |config|
  config.include StubFileHelper
end
