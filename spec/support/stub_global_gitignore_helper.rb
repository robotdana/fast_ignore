# frozen_string_literal: true

module StubGlobalGitignoreHelper
  def stub_blank_global_config
    return if defined?(@stub_blank_global_config)

    @stub_blank_global_config = true

    stub_env(
      XDG_CONFIG_HOME: nil,
      GIT_CONFIG_GLOBAL: nil,
      GIT_CONFIG_SYSTEM: nil,
      GIT_CONFIG_NOSYSTEM: nil
    )

    stub_file(nil, path: "#{Dir.pwd}/.git/config")
    stub_file(nil, path: "#{Dir.home}/.gitconfig")
    stub_file(nil, path: "#{Dir.home}/.config/git/config")
    stub_file(nil, path: '/usr/local/etc/gitconfig')
    stub_file(nil, path: "#{Dir.home}/.config/git/ignore")
  end
end

RSpec.configure do |config|
  config.include StubGlobalGitignoreHelper
end
