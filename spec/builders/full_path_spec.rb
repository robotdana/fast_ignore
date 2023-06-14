# frozen_string_literal: true

RSpec.describe PathList::Builders::FullPath do
  subject(:matcher) { described_class.build(path, allow_arg, nil) }

  let(:path) { '/path/to/exact/something' }
  let(:candidate_path) { path }
  let(:candidate) { PathList::Candidate.new(candidate_path, nil, nil, nil, nil) }
  let(:allow_arg) { true }

  context 'when allow' do
    subject(:matcher) { described_class.build_implicit(path, allow_arg, nil) }

    it 'builds a regex that matches parent and child somethings' do
      # i know it's bad but checking the ivar here is easy
      # and i want to match the regexp i expect to see
      expect(matcher.instance_variable_get(:@rule))
        .to eq %r{\Apath(?:\z|/to(?:\z|/exact(?:\z|/something\z)))}i
    end

    it 'matches exact path' do
      expect(matcher.match(PathList::Candidate.new(path, nil, nil, nil, nil))).to be :allow
    end

    it 'matches exact path regardless of case' do
      expect(matcher.match(PathList::Candidate.new(path.upcase, nil, nil, nil, nil))).to be :allow
    end

    it 'matches most parent path' do
      expect(matcher.match(PathList::Candidate.new('/path', nil, nil, nil, nil)))
        .to be :allow
    end

    it 'matches parent path' do
      expect(matcher.match(PathList::Candidate.new('/path/to', nil, nil, nil, nil)))
        .to be :allow
    end

    it "doesn't match child path" do
      expect(matcher.match(PathList::Candidate.new("#{path}/child", nil, nil, nil, nil)))
        .to be_nil
    end

    it "doesn't match path starting with the same string" do
      expect(matcher.match(PathList::Candidate.new("#{path}_part_2", nil, nil, nil, nil)))
        .to be_nil
    end

    it "doesn't match parent path starting with the same string" do
      expect(matcher.match(PathList::Candidate.new('/path/to/exact-ish/something', nil, nil, nil, nil)))
        .to be_nil
    end

    it "doesn't match path sibling" do
      expect(matcher.match(PathList::Candidate.new('/path/to/exact/other', nil, nil, nil, nil)))
        .to be_nil
    end

    it "doesn't match path concatenation" do
      expect(matcher.match(PathList::Candidate.new('/pathtoexactsomething', nil, nil, nil, nil))) # spellr:disable-line
        .to be_nil
    end
  end

  context 'when not allow' do
    let(:allow_arg) { false }
    subject(:matcher) { described_class.build(path, allow_arg, nil) }

    it 'builds a regex that matches exact something' do
      # i know it's bad but checking the ivar here is easy
      # and i want to match the regexp i expect to see
      expect(matcher.instance_variable_get(:@rule))
        .to eq %r{\Apath/to/exact/something\z}i
    end

    it 'matches exact path' do
      expect(matcher.match(PathList::Candidate.new(path, nil, nil, nil, nil))).to be :ignore
    end

    it 'matches exact path case insensitively' do
      expect(matcher.match(PathList::Candidate.new(path.upcase, nil, nil, nil, nil))).to be :ignore
    end

    it "doesn't match most parent path" do
      expect(matcher.match(PathList::Candidate.new('/path', nil, nil, nil, nil)))
        .to be_nil
    end

    it "doesn't match parent path" do
      expect(matcher.match(PathList::Candidate.new('/path/to', nil, nil, nil, nil)))
        .to be_nil
    end

    it "doesn't match child path" do
      expect(matcher.match(PathList::Candidate.new("#{path}/child", nil, nil, nil, nil)))
        .to be_nil
    end
  end
end
