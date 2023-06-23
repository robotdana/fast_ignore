# frozen_string_literal: true

RSpec.describe PathList::Builders::FullPath do
  subject(:matcher) { described_class.build(path, allow_arg, nil) }

  let(:path) { '/path/to/exact/something' }
  let(:candidate_path) { path }
  let(:candidate) { PathList::Candidate.new(candidate_path, true, nil, nil) }
  let(:allow_arg) { true }

  describe '.build_implicit' do
    subject(:matcher) { described_class.build_implicit(path, true, nil) }

    it 'builds a regex that matches parent and child somethings' do
      expect(matcher).to be_like(
        PathList::Matchers::PathRegexp.new(%r{\A/(?:path(?:/to(?:/exact(?:/something/|\z)|\z)|\z)|\z)}i, true)
      )
    end

    describe 'with root and relative path' do
      subject(:matcher) { described_class.build_implicit('./exact/something', true, '/path/to') }

      it 'builds a regex that matches parent and child somethings' do
        expect(matcher).to be_like(
          PathList::Matchers::PathRegexp.new(%r{\A/(?:path(?:/to(?:/exact(?:/something/|\z)|\z)|\z)|\z)}i, true)
        )
      end
    end

    it "doesn't need to match exact path" do
      expect(matcher.match(PathList::Candidate.new(path, true, nil, nil))).to be_nil
    end

    it 'matches most parent path' do
      expect(matcher.match(PathList::Candidate.new('/path', true, nil, nil)))
        .to be :allow
    end

    it 'matches most parent path regardless of case' do
      expect(matcher.match(PathList::Candidate.new('/PATH', true, nil, nil))).to be :allow
    end

    it 'matches parent path' do
      expect(matcher.match(PathList::Candidate.new('/path/to', true, nil, nil)))
        .to be :allow
    end

    it 'matches child path' do
      expect(matcher.match(PathList::Candidate.new("#{path}/child", true, nil, nil)))
        .to be :allow
    end

    it 'matches grandchild path' do
      expect(matcher.match(PathList::Candidate.new("#{path}/child/child", true, nil, nil)))
        .to be :allow
    end

    it "doesn't match path starting with the same string" do
      expect(matcher.match(PathList::Candidate.new("#{path}_part_2", true, nil, nil)))
        .to be_nil
    end

    it "doesn't match parent path starting with the same string" do
      expect(matcher.match(PathList::Candidate.new('/path/to/exact-ish/something', true, nil, nil)))
        .to be_nil
    end

    it "doesn't match path sibling" do
      expect(matcher.match(PathList::Candidate.new('/path/to/exact/other', true, nil, nil)))
        .to be_nil
    end

    it "doesn't match path concatenation" do
      expect(matcher.match(PathList::Candidate.new('/pathtoexactsomething', true, nil, nil))) # spellr:disable-line
        .to be_nil
    end
  end

  describe '.build' do
    subject(:matcher) { described_class.build(path, allow_arg, nil) }

    let(:allow_arg) { false }

    it 'builds a regex that matches exact something' do
      expect(matcher).to be_like(
        PathList::Matchers::PathRegexp.new(%r{\A/path/to/exact/something\z}i, false)
      )
    end

    it 'matches exact path' do
      expect(matcher.match(PathList::Candidate.new(path, true, nil, nil))).to be :ignore
    end

    it 'matches exact path case insensitively' do
      expect(matcher.match(PathList::Candidate.new(path.upcase, true, nil, nil))).to be :ignore
    end

    it "doesn't match most parent path" do
      expect(matcher.match(PathList::Candidate.new('/path', true, nil, nil)))
        .to be_nil
    end

    it "doesn't match parent path" do
      expect(matcher.match(PathList::Candidate.new('/path/to', true, nil, nil)))
        .to be_nil
    end

    it "doesn't match child path" do
      expect(matcher.match(PathList::Candidate.new("#{path}/child", true, nil, nil)))
        .to be_nil
    end
  end
end
