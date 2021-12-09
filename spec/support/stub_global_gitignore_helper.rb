# frozen_string_literal: true

module StubGlobalGitignoreHelper
  def stub_blank_global_config
    stub_env(
      XDG_CONFIG_HOME: nil
    )

    stub_file(nil, path: "#{Dir.pwd}/.git/config")
    stub_file(nil, path: "#{ENV['HOME']}/.gitconfig")
    stub_file(nil, path: "#{ENV['HOME']}/.config/git/config")
    stub_file(nil, path: '/etc/gitconfig')
    stub_file(nil, path: "#{ENV['HOME']}/.config/git/ignore")
  end
end

RSpec.configure do |config|
  config.include StubGlobalGitignoreHelper
end
