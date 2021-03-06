require "rubygems"
require "spec"
require "pp"

require "lib/textquery"

# Resources:
# - http://github.com/nathansobo/treetop
# - http://github.com/nathansobo/treetop/blob/master/examples/lambda_calculus/arithmetic.treetop
# - http://snippets.dzone.com/tag/Treetop
# - http://treetop.rubyforge.org/index.html
# - http://en.wikipedia.org/wiki/Parsing_expression_grammar
#

describe TextQuery do
  before(:all) do
    @parser = TextQuery.new
  end

  def parse(input)
    @parser.parse(input)
  end

  it "should look for exact word boundary match" do
    parse("text").eval("textstring").should be_false
    parse("text").eval("stringtext").should be_false
    parse("text").eval("some textstring").should be_false
    parse("text").eval("string of texts stuff").should be_false
    parse("$^").eval("string of $^* stuff").should be_false
  end

  it "should accept logical AND" do
    parse("a AND b").eval("c").should be_false
    parse("a AND b").eval("a").should be_false
    parse("a AND b").eval("b").should be_false

    parse("a AND b").eval("a b").should be_true
    parse("a AND b").eval("a c b").should be_true
  end

  it "should accept logical OR" do
    parse("a OR b").eval("c").should be_false
    parse("a OR b").eval("a").should be_true
    parse("a OR b").eval("b").should be_true

    parse("a OR b").eval("a b").should be_true
    parse("a OR b").eval("a c b").should be_true
  end

  it "should give precedence to AND" do
    # a AND (b OR c) == a AND b OR c
    parse("a AND b OR c").eval("a b c").should be_true
    parse("a AND b OR c").eval("a b").should be_true
    parse("a AND b OR c").eval("a c").should be_true

    parse("a AND b OR c").eval("b c").should be_false
    parse("a AND b OR c").eval("c").should be_false
    parse("a AND b OR c").eval("b").should be_false
  end

  it "should accept logical NOT" do
    %w[- NOT].each do |operator|
      parse("#{operator} a").eval("a").should be_false
      parse("#{operator} #{operator} a").eval("a").should be_true

      parse("#{operator} a OR a").eval("a").should be_true
      parse("a OR #{operator} a").eval("a").should be_true

      parse("b AND #{operator} a").eval("b").should be_true
      parse("b AND #{operator} a").eval("a").should be_false
    end
  end

  it "should evaluate sub expressions" do
    parse("(a AND b)").eval("a b").should be_true
    parse("(a OR b)").eval("a b").should be_true
    parse("(a AND NOT b)").eval("a b").should be_false

    parse("(a AND b) OR c").eval("a b c").should be_true
    parse("(a AND b) OR c").eval("a b").should be_true
    parse("(a AND b) OR c").eval("a c").should be_true

    parse("(a AND b) OR c").eval("c").should be_true
    parse("a AND (b OR c)").eval("c").should be_false

    # for the win...
    parse("a AND (b AND (c OR d))").eval("d a b").should be_true
  end

  it "should not trip up on placement of brackets" do
    parse("a AND (-b)").eval("a b").should    == parse("a AND -(b)").eval("a b")
    parse("(-a) AND b").eval("a b").should    == parse("-(a) AND b").eval("a b")
    parse("-(a) AND -(b)").eval("a b").should == parse("(-a) AND (-b)").eval("a b")

    parse("a OR (-b)").eval("a b").should     == parse("a OR -(b)").eval("a b")
    parse("(-a) OR b").eval("a b").should     == parse("-(a) OR b").eval("a b")
    parse("(-a) OR (-b)").eval("a b").should  == parse("-(a) OR -(b)").eval("a b")

    parse("a AND (b OR c)").eval("a b c").should be_true
    parse("a AND (b OR c)").eval("a b").should be_true
    parse("a AND (b OR c)").eval("a c").should be_true

    parse("(NOT a) OR a").eval("a").should be_true
    parse("(NOT a) AND (NOT b) AND (NOT c)").eval("b").should be_false
    parse("a AND (b AND (c OR NOT d))").eval("a b d").should be_false
    parse("a AND (b AND (c OR NOT d))").eval("a b c").should be_true
    parse("a AND (b AND (c OR NOT d))").eval("a b e").should be_true

    parse("a AND (b AND NOT (c OR d))").eval("a b").should be_true
    parse("a AND (b AND NOT (c OR d))").eval("a b c").should be_false
    parse("a AND (b AND NOT (c OR d))").eval("a b d").should be_false

    parse("-a AND -b AND -c").eval("e").should be_true
    parse("(-a) AND (-b) AND (-c)").eval("e").should be_true
    parse("(NOT a) AND (NOT b) AND (NOT c)").eval("e").should be_true
    parse("NOT a AND NOT b AND NOT c").eval("e").should be_true
  end

  it "should accept quoted strings" do
    parse("'some text'").eval("some text").should be_true
    parse("'some text string'").eval("some text").should be_false

    parse("'some text string'").eval("some text 1 string").should be_false
    parse("-'some text string'").eval("some text 1 string").should be_true

    parse("a AND -'a b'").eval("a b c").should be_false
    parse("a AND -'a b'").eval("a c b").should be_true

    parse("(a OR b) AND (-'a b c')").eval("a b c").should be_false
    parse("(a OR b) AND (-'a b c')").eval("a c b").should be_true
    parse("(a AND b) AND (-'a b c')").eval("a c b").should be_true

    # shakespeare got nothin' on ruby...
    parse("'to be' OR NOT 'to be'").eval("to be").should be_true
    parse('"to be" OR NOT "to be"').eval("to be").should be_true
  end

  it "should treat spaces as implicit ANDs" do
    parse("a b").eval("a c b").should be_true
    parse("b a c").eval("a c b").should be_true
    parse("b a c").eval("a c").should be_false

    parse("some text AND 'exact match'").eval("some exact match text").should be_true
    parse("some text AND 'exact match'").eval("some exact text match").should be_false

    parse("some text AND -'exact match'").eval("some exact text match").should be_true
    parse("some text AND -'exact match'").eval("some exact match").should be_false
  end

  it "should wrap the grammar API" do
    TextQuery.new("'to be' OR NOT 'to_be'").match?("to be").should be_true
    TextQuery.new("-test").match?("some string of text").should be_true
    TextQuery.new("NOT test").match?("some string of text").should be_true
    TextQuery.new("a AND b").match?("b a").should be_true
    TextQuery.new("a AND b").match?("a c").should be_false

    q = TextQuery.new("a AND (b AND NOT (c OR d))")
    q.match?("d a b").should be_false
    q.match?("b").should be_false
    q.match?("a b cdefg").should be_true
    q.eval("a b cdefg").should be_true
  end

  it "should support fuzzy matching" do
    parse("a~").eval("adf").should be_true
    parse("~a").eval("dfa").should be_true
    parse("~a~").eval("daf").should be_true

    parse("1~a~1").eval("daf").should be_true
    parse("2~a~1").eval("daf").should be_false
    parse("1~a~2").eval("daf").should be_false

    parse("~a~3").eval("daffy").should be_true
    parse("a~1").eval("adf").should be_false
    
    parse("a~1 AND b").eval("adf b").should be_false
    parse("a~2 AND b").eval("adf b").should be_true
    parse("a~3 AND b").eval("adf b").should be_false
  end

  it "should work on CJK text" do
    JP = "仕様変更は出し尽くしてしまいß"

    q = TextQuery.new("変更", :delim => '')
    q.eval(JP).should be_true
    q.eval("変ま").should be_false
    q.parse("は出").eval(JP).should be_true

    q = TextQuery.new
    q.parse("~出~").eval(JP).should be_true
    q.parse("~出~ AND NOT ~尽~").eval(JP).should be_false
    q.parse("~更は出~ OR ~尽く~").eval(JP).should be_true
  end

  it "should be case insensitive" do
    TextQuery.new("a", :ignorecase => true).match?("A b cD").should be_true
    TextQuery.new("a AND CD", :ignorecase => true).match?("A b cD").should be_true

    TextQuery.new("a", :ignorecase => false).match?("A b cD").should be_false
    TextQuery.new("a AND CD", :ignorecase => false).match?("A b cD").should be_false
  end

  context 'delimiters' do
    it 'should default to space delimiter' do
      TextQuery.new("a").match?("a b").should be_true
      TextQuery.new("a").match?("a*b").should be_false
    end

    it 'should accept a string delimiter' do
      TextQuery.new("a", :delim => "*").match?("a*b").should be_true
      TextQuery.new("a", :delim => "*").match?("a b").should be_false
    end

    it 'should accept an array of delimiters' do
      TextQuery.new("a", :delim => ["*"]).match?("a*b").should be_true
    end

    it 'should OR delimiters together when provided as an array' do
      TextQuery.new("a", :delim => ["*", "|"]).match?("a|b").should be_true
      TextQuery.new("a", :delim => ["*", "|"]).match?("a*b").should be_true
      TextQuery.new("a", :delim => ["*", "|"]).match?("a b").should be_false
    end

    it 'should not match just the delimiter' do
      TextQuery.new("a*b", :delim => ["*", "<"]).match?("over<under").should be_false
    end
  end
end
