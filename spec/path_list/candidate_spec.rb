# frozen_string_literal: true

RSpec.describe PathList::Candidate do
  subject(:candidate) do
    described_class.new(
      full_path,
      directory
    )
  end

  let(:full_path) { "/path/from/root/#{filename}" }
  let(:filename) { 'filename' }
  let(:directory) { false }

  if ENV['COVERAGE']
    describe '#original_inspect' do
      it 'returns the default inspect' do
        expect(candidate.original_inspect).to eq default_inspect_value(candidate)
      end
    end
  end

  describe '#inspect' do
    it 'returns the path with some bits for ease of reading' do
      expect(candidate.inspect).to eq '#<PathList::Candidate /path/from/root/filename>'
    end
  end

  describe '#parent' do
    before { allow(File).to receive_messages(exist?: nil, ftype: nil, directory?: nil) }

    it 'returns a candidate for the parent with preset directory value' do
      expect(candidate.parent).to be_like described_class.new('/path/from/root', true)
      expect(candidate.parent).to have_attributes(
        directory?: true
      )
      expect(File).not_to have_received(:directory?)
      expect(File).not_to have_received(:ftype)
    end

    context 'when the path is /' do
      let(:full_path) { '/' }

      it 'returns nil' do
        expect(candidate.parent).to be_nil
      end
    end
  end

  describe '#exists?' do
    within_temp_dir

    context 'when the file exists' do
      let(:full_path) { './foo' }

      before { create_file_list 'foo' }

      it 'is memoized when true' do
        allow(File).to receive(:ftype).and_call_original

        expect(candidate.exists?).to be true
        expect(File).to have_received(:ftype).once
        expect(candidate.exists?).to be true
        expect(File).to have_received(:ftype).once
      end
    end

    context 'when the file does not exist' do
      let(:full_path) { './foo' }

      it 'is memoized when false' do
        allow(File).to receive(:ftype).and_call_original

        expect(candidate.exists?).to be false
        expect(File).to have_received(:ftype).with('./foo').once
        expect(candidate.exists?).to be false
        expect(File).to have_received(:ftype).with('./foo').once
      end

      it 'is false when there is an error' do
        allow(File).to receive(:ftype).and_call_original
        allow(File).to receive(:ftype).with(full_path).and_raise(Errno::EACCES)

        expect(candidate.exists?).to be false
        expect(File).to have_received(:ftype).with('./foo').once
        expect(candidate.exists?).to be false
        expect(File).to have_received(:ftype).with('./foo').once
      end
    end
  end

  describe '#children' do
    within_temp_dir

    context 'when the directory has children' do
      let(:full_path) { './foo' }

      before { create_file_list 'foo/bar', 'foo/baz' }

      it 'is memoized' do
        allow(Dir).to receive(:children).and_call_original

        expect(candidate.children).to contain_exactly('bar', 'baz')
        expect(Dir).to have_received(:children).once
        expect(candidate.children).to contain_exactly('bar', 'baz')
        expect(Dir).to have_received(:children).once
      end
    end

    context 'when the directory is empty' do
      let(:full_path) { './foo' }

      before { create_dir 'foo' }

      it 'is memoized' do
        allow(Dir).to receive(:children).and_call_original

        expect(candidate.children).to be_empty
        expect(Dir).to have_received(:children).once
        expect(candidate.children).to be_empty
        expect(Dir).to have_received(:children).once
      end

      it 'is empty array when there is an error' do
        allow(Dir).to receive(:children).and_call_original
        allow(Dir).to receive(:children).with(full_path).and_raise(Errno::EACCES)

        expect(candidate.children).to eq []
        expect(Dir).to have_received(:children).once
        expect(candidate.children).to eq []
        expect(Dir).to have_received(:children).once
      end
    end
  end

  describe '#directory?', :aggregate_failures do
    within_temp_dir

    it 'treats soft links to directories as files rather than the directories they point to' do
      create_file_list 'foo_target/foo_child'
      create_symlink('foo' => 'foo_target')

      candidate = described_class.new(File.expand_path('foo'))
      expect(candidate).not_to be_directory
    end
  end

  describe '#shebang' do
    context 'when reading from the file system' do
      within_temp_dir

      let(:full_path) { './foo' }

      it 'returns the first line if it has a shebang' do
        create_file <<~RUBY, path: full_path
          #!/usr/bin/env ruby

          puts('it saves the first 64 characters by default, not that many')
        RUBY

        expect(candidate.shebang).to eq("#!/usr/bin/env ruby\n\nputs('it saves the first 64 characters by d")
          .or(eq("#!/usr/bin/env ruby\r\n\r\nputs('it saves the first 64 characters by"))
          .or(eq("#!/usr/bin/env ruby\n\nputs('it saves the first 64 characters by"))
      end

      it 'returns the first line of a long shebang' do
        create_file <<~RUBY, path: full_path
          #!/usr/bin/env ruby -w --disable-gems --verbose --enable-frozen-string-literal

          puts('yes')
        RUBY

        expect(candidate.shebang.chomp)
          .to eq '#!/usr/bin/env ruby -w --disable-gems --verbose --enable-frozen-string-literal'
      end

      it 'returns the first line of one line if it has a shebang' do
        create_file <<~RUBY, path: full_path
          #!/usr/bin/env ruby
        RUBY

        expect(candidate.shebang.chomp).to eq '#!/usr/bin/env ruby'
      end

      it 'returns the first line of one line if it has a shebang and no trailing newline' do
        create_file <<~RUBY.chomp, path: full_path
          #!/usr/bin/env ruby
        RUBY

        expect(candidate.shebang).to eq '#!/usr/bin/env ruby'
      end

      it 'returns an empty string if the first line is different' do
        create_file <<~RUBY, path: full_path
          # frozen_string_literal: true

          puts('no')
        RUBY

        expect(candidate.shebang).to eq ''
      end

      it 'returns an empty string if there is one line and no shebang' do
        create_file <<~RUBY, path: full_path
          puts('no')
        RUBY

        expect(candidate.shebang).to eq ''
      end

      it 'returns an empty string if there is one line with no trailing newline and no shebang' do
        create_file <<~RUBY.chomp, path: full_path
          puts('no')
        RUBY

        expect(candidate.shebang).to eq ''
      end

      it 'returns an empty string if there an error creating the file object' do
        allow(File).to receive(:new).and_raise(SystemCallError, 'error')

        expect(candidate.shebang).to eq ''
      end
    end
  end
end
