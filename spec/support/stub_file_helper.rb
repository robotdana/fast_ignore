# frozen_string_literal: true

module StubFileHelper
  def stub_file_original
    @stub_file_original ||= stub_file_attributes.each_key do |method|
      allow(::File).to receive(method).at_least(:once).and_call_original
    end
  end

  def stub_file(*lines, path:)
    stub_file_original

    stub_file_attributes(lines.join("\n")).each do |method, value|
      stub = allow(::File).to receive(method).with(path).at_least(:once)
      value.is_a?(Exception) ? stub.and_raise(value) : stub.and_return(value)
    end

    path
  end

  def stub_file_attributes(content = nil)
    exist = !content.nil?

    {
      readable?: exist,
      exist?: exist,
      read: content || Errno::ENOENT,
      readlines: content&.split("\n") || Errno::ENOENT
    }
  end
end

RSpec.configure do |config|
  config.include StubFileHelper
end
