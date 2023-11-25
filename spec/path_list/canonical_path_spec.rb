# frozen_string_literal: true

RSpec.describe(PathList::CanonicalPath) do
  let(:home) do
    File.expand_path(Dir.home)
  end

  describe '.case_insensitive?' do
    before do
      allow(described_class).to receive(:case_insensitive?).and_call_original
    end

    let(:mac) { RbConfig::CONFIG['host_os'].include?('darwin') }

    it 'matches my system expectations' do
      expect(described_class.case_insensitive?)
        .to be(windows? || mac)
    end

    it 'matches the fallback that creates a temp file' do
      test_file = Dir.mktmpdir + '/case_test'
      File.write(test_file, '')
      newly_created_file_found_insensitively = File.exist?(test_file.swapcase)

      expect(described_class.case_insensitive?)
        .to be(newly_created_file_found_insensitively)
    end
  end

  describe '.full_path_from' do
    it 'handles nil values' do
      expect(described_class.full_path_from(nil, nil))
        .to eq(Dir.pwd)
    end

    it 'handles `from` value being nil' do
      expect(described_class.full_path_from('foo', nil))
        .to eq("#{Dir.pwd}/foo")
    end

    it 'handles `to` value being nil' do
      expect(described_class.full_path_from(nil, '/bar'))
        .to eq("#{FSROOT}bar")
    end

    it 'appends path' do
      expect(described_class.full_path_from('foo', '/bar'))
        .to eq("#{FSROOT}bar/foo")
    end

    it 'replaces absolute path' do
      expect(described_class.full_path_from('/foo', '/bar'))
        .to eq("#{FSROOT}foo")
    end

    it 'expands home' do
      expect(described_class.full_path_from('~', '/bar'))
        .to eq(home)
    end

    it 'expands home with subdir' do
      expect(described_class.full_path_from('~/foo', '/bar'))
        .to eq("#{home}/foo")
    end

    context 'with ~user', skip: ('Not applicable on windows' if windows?) do
      it 'expands real user home' do
        expect(described_class.full_path_from("~#{os_user}", '/bar'))
          .to eq(home)
      end

      it 'expands real user home with subdir' do
        expect(described_class.full_path_from("~#{os_user}/foo", '/bar'))
          .to eq("#{home}/foo")
      end
    end

    it 'treats fake user home as relative' do
      expect(described_class.full_path_from('~nonsense-not-a-user-1437801', '/bar'))
        .to eq("#{FSROOT}bar/~nonsense-not-a-user-1437801")
    end

    it 'treats fake user home with subdir as relative' do
      expect(described_class.full_path_from('~nonsense-not-a-user-1437801/foo', '/bar'))
        .to eq("#{FSROOT}bar/~nonsense-not-a-user-1437801/foo")
    end
  end

  describe '.full_path' do
    it 'handles nil value' do
      expect(described_class.full_path(nil))
        .to eq(Dir.pwd)
    end

    it 'appends path to current path' do
      expect(described_class.full_path('foo'))
        .to eq("#{Dir.pwd}/foo")
    end

    it 'replaces absolute path' do
      expect(described_class.full_path('/foo'))
        .to eq("#{FSROOT}foo")
    end

    it 'expands home' do
      expect(described_class.full_path('~'))
        .to eq(home)
    end

    it 'expands home with subdir' do
      expect(described_class.full_path('~/foo'))
        .to eq("#{home}/foo")
    end

    context 'with ~user', skip: ('Not applicable on windows' if windows?) do
      it 'expands real user home' do
        expect(described_class.full_path("~#{os_user}"))
          .to eq(home)
      end

      it 'expands real user home with subdir' do
        expect(described_class.full_path("~#{os_user}/foo"))
          .to eq("#{home}/foo")
      end
    end

    it 'treats fake user home as relative' do
      expect(described_class.full_path('~nonsense-not-a-user-1437801'))
        .to eq("#{Dir.pwd}/~nonsense-not-a-user-1437801")
    end

    it 'treats fake user home with subdir as relative' do
      expect(described_class.full_path('~nonsense-not-a-user-1437801/foo'))
        .to eq("#{Dir.pwd}/~nonsense-not-a-user-1437801/foo")
    end
  end
end
