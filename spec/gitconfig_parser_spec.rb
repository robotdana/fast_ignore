# frozen_string_literal: true

RSpec.describe ::PathList::GitconfigParser do
  around { |e| within_temp_dir { e.run } }

  it 'returns nil for empty file' do
    create_file('', path: '.gitconfig')

    expect(described_class.parse('.gitconfig')).to be_nil
  end

  it 'raises for invalid file' do
    create_file('[', path: '.gitconfig')

    expect { described_class.parse('.gitconfig') }.to raise_error(::PathList::GitconfigParseError)
  end

  it 'raises for another invalid file' do
    create_file('x[', path: '.gitconfig')

    expect { described_class.parse('.gitconfig') }.to raise_error(::PathList::GitconfigParseError)
  end

  it 'returns nil for nonexistent file' do
    expect(described_class.parse('.gitconfig')).to be_nil
  end

  it 'returns nil for file with no [core]' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [remote "origin"]
        url = https://github.com/robotdana/path_list.git
        fetch = +refs/heads/*:refs/remotes/origin/*
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to be_nil
  end

  it 'returns nil for file with [core] but no excludesfile' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        mergeoptions = --no-edit
        hooksPath = ~/.dotfiles/hooks
        editor = mate --wait
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to be_nil
  end

  it 'returns value for file with excludesfile' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore')
  end

  it 'returns value for file with excludesfile after other stuff' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        mergeoptions = --no-edit
        excludesfile = ~/.gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore')
  end

  it 'returns value for file with excludesfile before other stuff' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/.gitignore
        mergeoptions = --no-edit
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore')
  end

  it 'returns value for file with excludesfile after boolean true key' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        ignoreCase
        excludesfile = ~/.gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore')
  end

  it 'returns value for file with [core] after other stuff' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [remote "origin"]
        url = https://github.com/robotdana/path_list.git
        fetch = +refs/heads/*:refs/remotes/origin/*
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore')
  end

  it 'returns value for file with [core] before other stuff' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/.gitignore
      [remote "origin"]
        url = https://github.com/robotdana/path_list.git
        fetch = +refs/heads/*:refs/remotes/origin/*
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore')
  end

  it 'returns nil for file with commented excludesfile line' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
      #  excludesfile = ~/.gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to be_nil
  end

  it 'returns value for file with excludesfile in quotes' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = "~/gitignore"
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns value for file with excludesFile in with camel casing' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesFile = ~/gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns value for file with excludesFile in with uppercase' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        EXCLUDESFILE = ~/gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns value for file with excludesFile in uppercase CORE' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [CORE]
        excludesFile = ~/gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns value for file with excludesfile after attributesfile in quotes' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        attributesfile = "~/gitattributes"
        excludesfile = ~/gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it "doesn't return value for file with excludesfile after attributesfile with line continuation" do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        attributesfile = ~/gitattributes\
        excludesfile = ~/gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to be_nil
  end

  it 'returns earlier value for file with excludesfile after attributesfile with line continuation' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/gitignore
        attributesfile = ~/gitattributes\
        excludesfile = ~/gitignore2
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns later value for file with multiple excludesfile' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/gitignore
        excludesfile = ~/gitignore2
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore2')
  end

  it 'returns value for file with excludesfile partially in quotes' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/git"ignore"
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns value for file with excludesfile with escaped quote character' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/git\\"ignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/git"ignore')
  end

  it 'returns value for file with excludesfile after attributesfile with escaped quote character' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        attributesfile = ~/git\\"attributes
        excludesfile = ~/gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns value for file with excludesfile with escaped newline (why)' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/git\\nignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq("~/git\nignore")
  end

  it 'returns value for file with excludesfile after attributesfile with escaped newline' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        attributesfile = ~/git\\nattributes
        excludesfile = ~/gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns value for file with excludesfile with escaped tab' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/git\\tignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq("~/git\tignore")
  end

  it 'returns value for file with excludesfile after attributesfile with escaped tab' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        attributesfile = ~/git\\tattributes
        excludesfile = ~/gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns value for file with excludesfile with literal space' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/git ignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/git ignore')
  end

  it 'returns value for file with excludesfile after attributesfile with literal space' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        attributesfile = ~/git attributes
        excludesfile = ~/gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  # i suspect this may be incorrect and it should actually be turned into a literal space character.
  it 'returns value for file with excludesfile with literal tab' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/git\tignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq("~/git\tignore")
  end

  it 'returns value for file with excludesfile after attributesfile with literal tab' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        attributesfile = ~/git\tattributes
        excludesfile = ~/gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns value for file with excludesfile with literal backspace' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/gith\\bignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns value for file with excludesfile after attributesfile with literal backspace' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        attributesfile = ~/git\battributes
        excludesfile = ~/gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns value for file with excludesfile with an escaped literal slash' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/git\\\\ignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/git\\ignore')
  end

  it 'returns value for file with excludesfile after attributesfile with escaped slash' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        attributesfile = ~/git\\\\attributes
        excludesfile = ~/gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns value for file with excludesfile with a ; comment' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/gitignore ; comment
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns value for file with excludesfile with a ; comment with no space' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/gitignore;comment
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns value for file with excludesfile with a # comment' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/gitignore # comment
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns value for file with excludesfile with a # in quotes' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = "~/git#ignore"
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/git#ignore')
  end

  it 'returns value for file with excludesfile with a ; in quotes' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = "~/git;ignore"
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/git;ignore')
  end

  it 'returns value with no trailing whitespace' do
    create_file("[core]\n  excludesfile = ~/gitignore    \n", path: '.gitconfig')

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'returns value for file with trailing whitespace when quoted' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = "~/gitignore   "
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore   ')
  end

  it 'continues with escaped newlines' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/git\\
      ignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/gitignore')
  end

  it 'raises for file with unclosed quote' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = "~/gitignore
    GITCONFIG

    expect { described_class.parse('.gitconfig') }.to raise_error(::PathList::GitconfigParseError)
  end

  it 'raises for file with unclosed quote and no trailing newline' do
    create_file(<<~GITCONFIG.chomp, path: '.gitconfig')
      [core]
        excludesfile = "~/gitignore
    GITCONFIG

    expect { described_class.parse('.gitconfig') }.to raise_error(::PathList::GitconfigParseError)
  end

  it 'raises for file with excludesfile after attributesfile with unclosed quote' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        attributesfile = "~/gitattributes
        excludesfile = ~/gitignore
    GITCONFIG

    expect { described_class.parse('.gitconfig') }.to raise_error(::PathList::GitconfigParseError)
  end

  it 'raises for file with excludesfile before attributesfile with unclosed quote and no trailing newline' do
    create_file(<<~GITCONFIG.chomp, path: '.gitconfig')
      [core]
        excludesfile = ~/gitignore
        attributesfile = "~/gitattributes
    GITCONFIG

    expect { described_class.parse('.gitconfig') }.to raise_error(::PathList::GitconfigParseError)
  end

  it 'raises for file with unclosed quote followed by more stuff' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = "~/gitignore
        mergeoptions = --no-edit
    GITCONFIG

    expect { described_class.parse('.gitconfig') }.to raise_error(::PathList::GitconfigParseError)
  end

  it 'raises for file with quote containing a newline' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = "~/git
      ignore"
    GITCONFIG

    expect { described_class.parse('.gitconfig') }.to raise_error(::PathList::GitconfigParseError)
  end

  it 'raises for file with excludesfile after attributesfile with quoted newline' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        attributesfile = "~/git
      attributes"
        excludesfile = ~/gitignore
    GITCONFIG

    expect { described_class.parse('.gitconfig') }.to raise_error(::PathList::GitconfigParseError)
  end

  it 'raises for file with invalid \ escape' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = "~/gitignore\\x"
    GITCONFIG

    expect { described_class.parse('.gitconfig') }.to raise_error(::PathList::GitconfigParseError)
  end

  it 'raises for file with excludesfile after attributesfile with invalid escape' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        attributesfile = "~/git\\xattributes
        excludesfile = ~/gitignore
    GITCONFIG

    expect { described_class.parse('.gitconfig') }.to raise_error(::PathList::GitconfigParseError)
  end

  it 'returns value for file when included' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [include]
        path = .gitconfig_include
    GITCONFIG

    create_file(<<~GITCONFIG, path: '.gitconfig_include')
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore')
  end

  it 'returns value for file when includeif onbranch' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [includeif "onbranch:main"]
        path = .gitconfig_include
    GITCONFIG

    create_file('ref: refs/heads/main', path: '.git/HEAD')

    create_file(<<~GITCONFIG, path: '.gitconfig_include')
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore')
  end

  it 'returns value for file when includeif onbranch pattern' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [includeif "onbranch:m*"]
        path = .gitconfig_include
    GITCONFIG

    create_file('ref: refs/heads/main', path: '.git/HEAD')

    create_file(<<~GITCONFIG, path: '.gitconfig_include')
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore')
  end

  it 'returns value for file when includeif onbranch pattern ending in /' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [includeif "onbranch:feature/"]
        path = .gitconfig_include
    GITCONFIG

    create_file('ref: refs/heads/feature/saving', path: '.git/HEAD')

    create_file(<<~GITCONFIG, path: '.gitconfig_include')
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore')
  end

  it 'returns nil for file when includeif onbranch is not the right branch' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [includeif "onbranch:main"]
        path = .gitconfig_include
    GITCONFIG

    create_file('ref: refs/heads/dev', path: '.git/HEAD')

    create_file(<<~GITCONFIG, path: '.gitconfig_include')
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to be_nil
  end

  it 'returns nil for file when includeif nonsense' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [includeif "nonsense"]
        path = .gitconfig_include
    GITCONFIG

    create_file('ref: refs/heads/dev', path: '.git/HEAD')

    create_file(<<~GITCONFIG, path: '.gitconfig_include')
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to be_nil
  end

  it 'returns nil for file when includeif onbranch and no .git dir' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [includeif "onbranch:main"]
        path = .gitconfig_include
    GITCONFIG

    create_file(<<~GITCONFIG, path: '.gitconfig_include')
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to be_nil
  end

  it 'raises for file when includeif onbranch with newline' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [includeif "onbranch:ma
      in"]
        path = .gitconfig_include
    GITCONFIG

    create_file(<<~GITCONFIG, path: '.gitconfig_include')
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    expect { described_class.parse('.gitconfig') }.to raise_error ::PathList::GitconfigParseError
  end

  it 'raises for file when includeif nonsense with newline' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [includeif "nonsense
      in"]
        path = .gitconfig_include
    GITCONFIG

    create_file(<<~GITCONFIG, path: '.gitconfig_include')
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    expect { described_class.parse('.gitconfig') }.to raise_error ::PathList::GitconfigParseError
  end

  it 'raises for file when includeif onbranch with null' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [includeif "onbranch:ma\0in"]
        path = .gitconfig_include
    GITCONFIG

    create_file(<<~GITCONFIG, path: '.gitconfig_include')
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    expect { described_class.parse('.gitconfig') }.to raise_error ::PathList::GitconfigParseError
  end

  it 'returns value for file when includeif gitdir matches leading **/' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [includeif "gitdir:**/.git"]
        path = .gitconfig_include
    GITCONFIG

    create_file(<<~GITCONFIG, path: '.gitconfig_include')
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore')
  end

  it 'returns value for file when includeif gitdir/i matches leading **/' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [includeif "gitdir/i:**/.GIT"]
        path = .gitconfig_include
    GITCONFIG

    create_file(<<~GITCONFIG, path: '.gitconfig_include')
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore')
  end

  it 'returns value for file when includeif gitdir matches trailing /' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [includeif "gitdir:#{Dir.pwd}/"]
        path = .gitconfig_include
    GITCONFIG

    create_file(<<~GITCONFIG, path: '.gitconfig_include')
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore')
  end

  it "doesn't leak the section for file when included" do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/.gitignore
      [include]
        path = .gitconfig_include
        excludesfile = ~/.gitignore2
    GITCONFIG

    create_file(<<~GITCONFIG, path: '.gitconfig_include')
      [core]
        attributesfile = ~/.gitattributes
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore')
  end

  it 'returns the most recent value when included' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [core]
        excludesfile = ~/.gitignore
      [include]
        path = .gitconfig_include
    GITCONFIG

    create_file(<<~GITCONFIG, path: '.gitconfig_include')
      [core]
        excludesfile = ~/.gitignore2
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore2')
  end

  it 'returns the most recent value after included' do
    create_file(<<~GITCONFIG, path: '.gitconfig')

      [include]
        path = .gitconfig_include
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    create_file(<<~GITCONFIG, path: '.gitconfig_include')
      [core]
        excludesfile = ~/.gitignore2
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore')
  end

  it 'raises when including itself' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [include]
        path = .gitconfig
    GITCONFIG

    expect { described_class.parse('.gitconfig') }.to raise_error(::PathList::GitconfigParseError)
  end

  it 'returns value for file when included nestedly' do
    create_file(<<~GITCONFIG, path: '.gitconfig')
      [include]
        path = .gitconfig_include_1
    GITCONFIG

    create_file(<<~GITCONFIG, path: '.gitconfig_include_1')
      [include]
        path = .gitconfig_include_2
    GITCONFIG

    create_file(<<~GITCONFIG, path: '.gitconfig_include_2')
      [core]
        excludesfile = ~/.gitignore
    GITCONFIG

    expect(described_class.parse('.gitconfig')).to eq('~/.gitignore')
  end
end
