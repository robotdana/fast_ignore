RSpec.describe ::PathList::Patterns do
  subject(:matchers) do
    described_class.new(
      *patterns_arg,
      from_file: from_file,
      format: format_arg,
      root: root,
      allow: allow_arg,
      label: label
    ).build
  end

  let(:patterns) { [] }
  let(:patterns_arg) { from_file ? [] : patterns }
  let(:from_file) { nil }
  let(:format_arg) { nil }
  let(:root) { nil }
  let(:allow_arg) { false }
  let(:label) { nil }

  around do |e|
    if from_file
      within_temp_dir { e.run }
    else
      e.run
    end
  end

  before do
    stub_file patterns.join("\n"), from_file if from_file
  end

  describe 'with blank patterns' do
    context 'when ignore' do
      let(:allow_arg) { false }

      it 'matches everything' do
        expect(matchers).to eq PathList::Matchers::Allow
      end
    end

    context 'when allow' do
      let(:allow_arg) { true }

      it 'matches everything' do
        expect(matchers).to eq PathList::Matchers::Allow
      end
    end
  end

  describe 'with basic patterns' do
    let(:patterns) { 'a' }
    let(:root) { '/' }

    context 'when ignore' do
      let(:allow_arg) { false }

      it 'ignores a' do
        expect(matchers).to eq PathList::Matchers::LastMatch.new([
          # default
          PathList::Matchers::Allow,
          # actual matchers
          PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a\z}i, false, false, false)
        ])
      end
    end

    context 'when allow' do
      let(:allow_arg) { true }

      it 'allows a, and implicitly any children of a' do
        expect(matchers).to eq PathList::Matchers::LastMatch.new([
          # default
          PathList::Matchers::Ignore,
          # implicit
          PathList::Matchers::Any.new([
            PathList::Matchers::AllowAnyDir,
            PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a/}i, false, true, true),
            # actual matchers
            PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a\z}i, false, true, false)
          ])
        ])
      end
    end

    context 'with a root' do
      let(:root) { '/b' }

      context 'when ignore' do
        let(:allow_arg) { false }

        it 'ignores a' do
          expect(matchers).to eq PathList::Matchers::LastMatch.new([
            PathList::Matchers::Allow,
            PathList::Matchers::WithinDir.new(
              '/b/',
              PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a\z}i, false, false, false)
            )
          ])
        end
      end

      context 'when allow' do
        let(:allow_arg) { true }

        it 'allows a, and implicitly any children of a' do
          expect(matchers).to eq PathList::Matchers::LastMatch.new([
            PathList::Matchers::Ignore,
            PathList::Matchers::Any.new([
              PathList::Matchers::MatchIfDir.new(
                PathList::Matchers::PathRegexp.new(/\Ab\z/i, true, true, true)
              ),
              PathList::Matchers::WithinDir.new(
                '/b/',
                PathList::Matchers::Any.new([
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a\z}i, false, true, false),
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a/}i, false, true, true)
                ])
              )
            ])
          ])
        end
      end
    end
  end
end
