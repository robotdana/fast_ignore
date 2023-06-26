# frozen_string_literal: true

RSpec.describe PathList::Candidate do
  subject(:candidate) do
    described_class.build(
      full_path,
      directory,
      exists
    )
  end

  let(:full_path) { "/path/from/root/#{filename}" }
  let(:filename) { 'filename' }
  let(:directory) { false }
  let(:exists) { true }

  describe '#original_inspect' do
    it 'returns the default inspect' do
      expect(candidate.original_inspect).to eq default_inspect_value(candidate)
    end
  end

  describe '#inspect' do
    it 'returns the path with some bits for ease of reading' do
      expect(candidate.inspect).to eq '#<PathList::Candidate /path/from/root/filename>'
    end
  end

  describe '#exists?' do
    context 'when reading from the file system' do
      around { |e| within_temp_dir { e.run } }

      let(:exists) { nil }

      context 'when the file exists' do
        let(:full_path) { './foo' }

        before { create_file_list 'foo' }

        it 'is memoized when true' do
          allow(File).to receive(:exist?).and_call_original

          expect(candidate.exists?).to be true
          expect(File).to have_received(:exist?).once
          expect(candidate.exists?).to be true
          expect(File).to have_received(:exist?).once
        end
      end

      context 'when the file does not exist' do
        let(:full_path) { './foo' }

        it 'is memoized when false' do
          allow(File).to receive(:exist?).and_call_original

          expect(candidate.exists?).to be false
          expect(File).to have_received(:exist?).with('./foo').once
          expect(candidate.exists?).to be false
          expect(File).to have_received(:exist?).with('./foo').once
        end

        it 'is false when there is an error' do
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(full_path).and_raise(Errno::EACCES)

          expect(candidate.exists?).to be false
          expect(File).to have_received(:exist?).once
          expect(candidate.exists?).to be false
          expect(File).to have_received(:exist?).once
        end
      end
    end

    context 'when not reading from the file system' do
      before { hide_const('::File') }

      context 'when the file exists' do
        let(:exists) { true }

        it 'is true when true' do
          expect(candidate.exists?).to be true
          expect(candidate.exists?).to be true
        end
      end

      context 'when the file does not exist' do
        let(:exists) { false }

        it 'is false when false' do
          expect(candidate.exists?).to be false
          expect(candidate.exists?).to be false
        end
      end
    end
  end

  describe '#first_line' do
    context 'when reading from the file system' do
      around { |e| within_temp_dir { e.run } }

      let(:full_path) { './foo' }

      it 'returns the first line if it has a shebang' do
        create_file <<~RUBY, path: full_path
          #!/usr/bin/env ruby

          puts('it saves the first 64 characters by default, not that many')
        RUBY

        expect(candidate.first_line).to eq "#!/usr/bin/env ruby\n\nputs('it saves the first 64 characters by d"
      end

      it 'returns the first line of a long shebang' do
        create_file <<~RUBY, path: full_path
          #!/usr/bin/env ruby -w --disable-gems --verbose --enable-frozen-string-literal

          puts('yes')
        RUBY

        expect(candidate.first_line)
          .to eq "#!/usr/bin/env ruby -w --disable-gems --verbose --enable-frozen-string-literal\n"
      end

      it 'returns the first line of one line if it has a shebang' do
        create_file <<~RUBY, path: full_path
          #!/usr/bin/env ruby
        RUBY

        expect(candidate.first_line).to eq "#!/usr/bin/env ruby\n"
      end

      it 'returns the first line of one line if it has a shebang and no trailing newline' do
        create_file <<~RUBY.chomp, path: full_path
          #!/usr/bin/env ruby
        RUBY

        expect(candidate.first_line).to eq '#!/usr/bin/env ruby'
      end

      it 'returns an empty string if the first line is different' do
        create_file <<~RUBY, path: full_path
          # frozen_string_literal: true

          puts('no')
        RUBY

        expect(candidate.first_line).to eq ''
      end

      it 'returns an empty string if there is one line and no shebang' do
        create_file <<~RUBY, path: full_path
          puts('no')
        RUBY

        expect(candidate.first_line).to eq ''
      end

      it 'returns an empty string if there is one line with no trailing newline and no shebang' do
        create_file <<~RUBY.chomp, path: full_path
          puts('no')
        RUBY

        expect(candidate.first_line).to eq ''
      end

      it 'returns an empty string if there an error creating the file object' do
        allow(File).to receive(:new).and_raise(SystemCallError, 'error')

        expect(candidate.first_line).to eq ''
      end
    end

    context 'when not reading from the file system', skip: 'this moved to query methods' do
      before { hide_const('::File') }

      context 'when the first line has a shebang' do
        let(:content) do
          <<~RUBY
            #!/usr/bin/env ruby

            puts('yes')
          RUBY
        end

        it 'returns the first line' do
          expect(candidate.first_line).to eq '#!/usr/bin/env ruby'
        end

        it 'stores the first line' do
          expect(candidate.instance_variable_get(:@first_line)).to eq '#!/usr/bin/env ruby'
        end
      end

      context 'when the first line of one line has a shebang' do
        let(:content) do
          <<~RUBY
            #!/usr/bin/env ruby
          RUBY
        end

        it 'returns the first line' do
          expect(candidate.first_line).to eq '#!/usr/bin/env ruby'
        end

        it 'stores the first line' do
          expect(candidate.instance_variable_get(:@first_line)).to eq '#!/usr/bin/env ruby'
        end
      end

      context 'when the first line of one line has a shebang with no trailing newline' do
        let(:content) do
          <<~RUBY.chomp
            #!/usr/bin/env ruby
          RUBY
        end

        it 'returns the first line' do
          expect(candidate.first_line).to eq '#!/usr/bin/env ruby'
        end

        it 'stores the first line' do
          expect(candidate.instance_variable_get(:@first_line)).to eq '#!/usr/bin/env ruby'
        end
      end

      context "when the first line hasn't a shebang" do
        let(:content) do
          <<~RUBY
            # frozen_string_literal: true

            puts('no')
          RUBY
        end

        it 'returns an empty string' do
          expect(candidate.first_line).to eq ''
        end

        it 'stores an empty string' do
          expect(candidate.instance_variable_get(:@first_line)).to eq ''
        end
      end

      context "when the first line of one line hasn't a shebang" do
        let(:content) do
          <<~RUBY
            # frozen_string_literal: true
          RUBY
        end

        it 'returns an empty string' do
          expect(candidate.first_line).to eq ''
        end

        it 'stores an empty string' do
          expect(candidate.instance_variable_get(:@first_line)).to eq ''
        end
      end

      context "when the first line of one line with no trailing newline hasn't a shebang" do
        let(:content) do
          <<~RUBY.chomp
            puts('no')
          RUBY
        end

        it 'returns an empty string' do
          expect(candidate.first_line).to eq ''
        end

        it 'stores an empty string' do
          expect(candidate.instance_variable_get(:@first_line)).to eq ''
        end
      end
    end
  end
end
