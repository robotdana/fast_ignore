# frozen_string_literal: true

RSpec.describe PathList::Builders::FullPath do
  subject(:matcher) { described_class.build(path, allow_arg, nil) }

  let(:path) { '/path/to/exact/something' }
  let(:candidate_path) { path }
  let(:candidate) { PathList::Candidate.new(candidate_path, nil, true, nil, nil) }
  let(:allow_arg) { true }

  context 'when allow' do
    subject(:matcher) { described_class.build_implicit(path, allow_arg, nil) }

    it 'builds a regex that matches parent and child somethings' do
      expect(matcher).to eq(PathList::Matchers::MatchIfDir.new(
        PathList::Matchers::PathRegexp.new(%r{\A/path(?:\z|/to(?:\z|/exact(?:\z|/something\z)))}i, true)
      ))
    end

    it 'matches exact path' do
      expect(matcher.match(PathList::Candidate.new(path, nil, true, nil, nil))).to be :allow
    end

    it 'matches exact path regardless of case' do
      expect(matcher.match(PathList::Candidate.new(path.upcase, nil, true, nil, nil))).to be :allow
    end

    it 'matches most parent path' do
      expect(matcher.match(PathList::Candidate.new('/path', nil, true, nil, nil)))
        .to be :allow
    end

    it 'matches parent path' do
      expect(matcher.match(PathList::Candidate.new('/path/to', nil, true, nil, nil)))
        .to be :allow
    end

    it "doesn't match child path" do
      expect(matcher.match(PathList::Candidate.new("#{path}/child", nil, true, nil, nil)))
        .to be_nil
    end

    it "doesn't match path starting with the same string" do
      expect(matcher.match(PathList::Candidate.new("#{path}_part_2", nil, true, nil, nil)))
        .to be_nil
    end

    it "doesn't match parent path starting with the same string" do
      expect(matcher.match(PathList::Candidate.new('/path/to/exact-ish/something', nil, true, nil, nil)))
        .to be_nil
    end

    it "doesn't match path sibling" do
      expect(matcher.match(PathList::Candidate.new('/path/to/exact/other', nil, true, nil, nil)))
        .to be_nil
    end

    it "doesn't match path concatenation" do
      expect(matcher.match(PathList::Candidate.new('/pathtoexactsomething', nil, true, nil, nil))) # spellr:disable-line
        .to be_nil
    end
  end

  context 'when not allow' do
    subject(:matcher) { described_class.build(path, allow_arg, nil) }

    let(:allow_arg) { false }

    it 'builds a regex that matches exact something' do
      expect(matcher).to eq(PathList::Matchers::MatchIfDir.new(
        PathList::Matchers::PathRegexp.new(%r{\A/path/to/exact/something\z}i, false)
      ))
    end

    it 'matches exact path' do
      expect(matcher.match(PathList::Candidate.new(path, nil, true, nil, nil))).to be :ignore
    end

    it 'matches exact path case insensitively' do
      expect(matcher.match(PathList::Candidate.new(path.upcase, nil, true, nil, nil))).to be :ignore
    end

    it "doesn't match most parent path" do
      expect(matcher.match(PathList::Candidate.new('/path', nil, true, nil, nil)))
        .to be_nil
    end

    it "doesn't match parent path" do
      expect(matcher.match(PathList::Candidate.new('/path/to', nil, true, nil, nil)))
        .to be_nil
    end

    it "doesn't match child path" do
      expect(matcher.match(PathList::Candidate.new("#{path}/child", nil, true, nil, nil)))
        .to be_nil
    end
  end
end
