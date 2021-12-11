# frozen_string_literal: true

module StubGlobalGitignoreHelper
  def stub_blank_global_config # rubocop:disable Metrics/MethodLength
    stub_env(
      XDG_CONFIG_HOME: nil,
      GIT_CONFIG_GLOBAL: nil,
      GIT_CONFIG_SYSTEM: nil,
      GIT_CONFIG_NOSYSTEM: nil
    )

    stub_file(nil, path: "#{Dir.pwd}/.git/config")
    stub_file(nil, path: "#{ENV['HOME']}/.gitconfig")
    stub_file(nil, path: "#{ENV['HOME']}/.config/git/config")
    stub_file(nil, path: '/usr/local/etc/gitconfig')
    stub_file(nil, path: "#{ENV['HOME']}/.config/git/ignore")
  end
end

RSpec.configure do |config|
  config.include StubGlobalGitignoreHelper
end
