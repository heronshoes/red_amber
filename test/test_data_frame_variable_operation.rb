# frozen_string_literal: true

require 'test_helper'

class DataFrameVariableOperationTest < Test::Unit::TestCase
  include TestHelper
  include RedAmber

  setup do
    @df = DataFrame.new(
      a: [1, 2, 3],
      b: [0.0, Float::NAN, nil],
      c: %w[A B C],
      d: [true, false, nil]
    )
    @df2 = DataFrame.new(
      index: [0, 1, 2, 3, nil],
      float: [0.0, 1.1,  2.2, Float::NAN, nil],
      string: ['A', 'B', 'C', 'D', nil],
      bool: [true, false, true, false, nil]
    )
  end

  sub_test_case 'pick' do
    test 'Empty dataframe' do
      df = DataFrame.new
      assert_true df.pick.empty?
      assert_true df.pick(nil).empty?
      assert_raise(IndexError) { df.pick(1) }
    end

    test 'pick by arguments' do
      assert_raise(DataFrameArgumentError) { @df.pick(:index) { :block } }

      assert_true @df.pick.empty? # pick nothing
      assert_true @df.equal?(@df.pick(@df.keys)) # pick all

      str = <<~STR
        RedAmber::DataFrame : 3 x 1 Vector
        Vector : 1 numeric
        # key type  level data_preview
        0 :a  uint8     3 [1, 2, 3]
      STR
      assert_equal str, @df.pick(:a).tdr_str
      assert_equal str, @df.pick(0).tdr_str

      str = <<~STR
        RedAmber::DataFrame : 3 x 2 Vectors
        Vectors : 2 numeric
        # key type   level data_preview
        0 :a  uint8      3 [1, 2, 3]
        1 :b  double     3 [0.0, NaN, nil], 1 NaN, 1 nil
      STR
      assert_equal str, @df.pick(:a, :b).tdr_str
      assert_equal str, @df.pick(%i[a b]).tdr_str
      assert_equal str, @df.pick(%w[a b]).tdr_str
      assert_equal str, @df.pick(0, 1).tdr_str
      assert_equal str, @df.pick([0, 1]).tdr_str
      assert_equal str, @df.pick([0, -3]).tdr_str
      assert_equal str, @df.pick(0..1).tdr_str
      assert_equal str, @df.pick(:a..:b).tdr_str
      assert_equal str, @df.pick(0...2).tdr_str
      assert_equal str, @df.pick(..1).tdr_str
      assert_equal str, @df.pick(true, true, false, nil).tdr_str
      assert_raise(DataFrameArgumentError) { @df.pick(..:b) }
      assert_raise(IndexError) { @df.pick(0..5) }
    end

    test 'pick by endless Range' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 2 Vectors
        Vectors : 1 string, 1 boolean
        # key type    level data_preview
        0 :c  string      3 ["A", "B", "C"]
        1 :d  boolean     3 [true, false, nil], 1 nil
      STR
      assert_equal str, @df.pick(2..).tdr_str
      assert_equal str, @df.pick(-2..).tdr_str
      assert_equal str, @df.pick(2...).tdr_str
      assert_equal str, @df.pick(2..-1).tdr_str
      assert_raise(DataFrameArgumentError) { @df.pick(:c..) }
    end

    test 'pick by block' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 1 Vector
        Vector : 1 boolean
        # key type    level data_preview
        0 :d  boolean     3 [true, false, nil], 1 nil
      STR
      assert_true @df.pick {}.empty? # pick nothing
      assert_equal str, @df.pick { :d }.tdr_str
      assert_equal str, @df.pick { [:d] }.tdr_str
      assert_equal str, @df.pick { 3 }.tdr_str
      assert_equal str, @df.pick { [3] }.tdr_str
      assert_equal str, @df.pick { vectors.map(&:boolean?) }.tdr_str

      str = <<~STR
        RedAmber::DataFrame : 3 x 2 Vectors
        Vectors : 2 numeric
        # key type   level data_preview
        0 :a  uint8      3 [1, 2, 3]
        1 :b  double     3 [0.0, NaN, nil], 1 NaN, 1 nil
      STR
      assert_equal str, @df.pick { %i[a b] }.tdr_str
      assert_equal str, @df.pick { vectors.map(&:numeric?) }.tdr_str
      assert_equal str, @df.pick { Vector.new(true, true, false, nil) }.tdr_str # Vector
      assert_equal str, @df.pick { [0, 1] }.tdr_str
    end

    test 'pick by mixed args' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 3 Vectors
        Vectors : 1 numeric, 1 string, 1 boolean
        # key type    level data_preview
        0 :c  string      3 ["A", "B", "C"]
        1 :d  boolean     3 [true, false, nil], 1 nil
        2 :a  uint8       3 [1, 2, 3]
      STR
      assert_equal str, @df.pick(2..-1, 0).tdr_str
      assert_equal str, @df.pick(:c..:d, :a).tdr_str
      assert_equal str, @df.pick { [2..-1, 0] }.tdr_str
      assert_equal str, @df.pick { [:c..:d, :a] }.tdr_str
      assert_equal str, @df.pick((:c..:d).each, 0).tdr_str # Enumerator
      assert_equal str, @df.pick(2.5, -0.2, 0.1).tdr_str # float
      assert_equal str, @df.pick(Vector.new(2, 3, 0)).tdr_str # Vector
      assert_equal str, @df.pick(2, 3, nil, 0).tdr_str # nil is ignored
      assert_equal str, @df.pick(Arrow::Array.new([2, 3, 0])).tdr_str # else clause in _parse_element
    end

    test 'pick duplicate keys' do
      assert_raise(DataFrameArgumentError) { @df.pick(0, 1, 0) }
      assert_raise(DataFrameArgumentError) { @df.pick { %i[a a] } }
    end
  end

  sub_test_case 'drop' do
    test 'Empty dataframe' do
      df = DataFrame.new
      assert_true df.drop.empty?
      assert_true df.drop(:key).empty?
    end

    test 'drop nothing' do
      assert_true @df.equal?(@df.drop)
      assert_true @df.equal?(@df.drop([]))
      assert_true @df.equal?(@df.drop(nil))
      assert_true @df.equal?(@df.drop([nil]))
      assert_true @df.equal?(@df.drop { [] })
      assert_true @df.equal?(@df.drop { nil })
      assert_true @df.equal?(@df.drop { [nil] })
    end

    test 'drop by arguments' do
      assert_raise(DataFrameArgumentError) { @df.drop(:a) { :block } }

      assert_true @df.drop(@df.keys).empty? # drop all

      str = <<~STR
        RedAmber::DataFrame : 3 x 2 Vectors
        Vectors : 1 numeric, 1 boolean
        # key type    level data_preview
        0 :a  uint8       3 [1, 2, 3]
        1 :d  boolean     3 [true, false, nil], 1 nil
      STR
      assert_equal str, @df.drop(:b, :c).tdr_str
      assert_equal str, @df.drop(%i[b c]).tdr_str
      assert_equal str, @df.drop(%w[b c]).tdr_str
      assert_equal str, @df.drop(1, -2).tdr_str
      assert_equal str, @df.drop(1..2).tdr_str
      assert_equal str, @df.drop(:b..:c).tdr_str
      assert_equal str, @df.drop(1...3).tdr_str
      assert_equal str, @df.drop(false, true, true, nil).tdr_str
      assert_true @df.drop(..3).empty?
      assert_raise(DataFrameArgumentError) { @df.drop(..:d) }
      assert_raise(IndexError) { @df.drop(0..5) }
    end

    test 'drop by endless Range' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 2 Vectors
        Vectors : 2 numeric
        # key type   level data_preview
        0 :a  uint8      3 [1, 2, 3]
        1 :b  double     3 [0.0, NaN, nil], 1 NaN, 1 nil
      STR
      assert_equal str, @df.drop(2..).tdr_str
      assert_raise(DataFrameArgumentError) { @df.drop(:c..) }
      assert_equal str, @df.drop(-2..).tdr_str
      assert_equal str, @df.drop(2...).tdr_str
      assert_equal str, @df.drop(2..-1).tdr_str
    end

    test 'drop by block' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 3 Vectors
        Vectors : 2 numeric, 1 string
        # key type   level data_preview
        0 :a  uint8      3 [1, 2, 3]
        1 :b  double     3 [0.0, NaN, nil], 1 NaN, 1 nil
        2 :c  string     3 ["A", "B", "C"]
      STR
      assert_equal str, @df.drop { 3 }.tdr_str
      assert_equal str, @df.drop { [3] }.tdr_str
      assert_equal str, @df.drop { :d }.tdr_str
      assert_equal str, @df.drop { [:d] }.tdr_str
      assert_equal str, @df.drop { vectors.map(&:boolean?) }.tdr_str
      assert_equal str, @df.drop { Vector.new(false, false, nil, true) }.tdr_str # Vector
      assert_equal str, @df.drop { -1 }.tdr_str

      str = <<~STR
        RedAmber::DataFrame : 3 x 2 Vectors
        Vectors : 1 string, 1 boolean
        # key type    level data_preview
        0 :c  string      3 ["A", "B", "C"]
        1 :d  boolean     3 [true, false, nil], 1 nil
      STR
      assert_equal str, @df.drop { [0, 1] }.tdr_str
      assert_equal str, @df.drop { vectors.map(&:numeric?) }.tdr_str
      assert_equal str, @df.drop { [1, 0] }.tdr_str
      assert_equal str, @df.drop { %i[b a] }.tdr_str
      assert_equal str, @df.drop { [:a..:b] }.tdr_str
    end

    test 'drop by mixed args' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 1 Vector
        Vector : 1 numeric
        # key type  level data_preview
        0 :a  uint8     3 [1, 2, 3]
      STR
      assert_equal str, @df.drop(2..-1, 1).tdr_str
      assert_equal str, @df.drop(:c..:d, :b).tdr_str
      assert_equal str, @df.drop { [2..-1, 1] }.tdr_str
      assert_equal str, @df.drop { [:b, :c..:d] }.tdr_str
      assert_equal str, @df.drop((:c..:d).each, :b).tdr_str # Enumerator
      assert_equal str, @df.drop(2.5, -0.2, 1.1).tdr_str # float
      assert_equal str, @df.drop(Vector.new(2, 3, 1)).tdr_str # Vector
      assert_equal str, @df.drop(2, 3, nil, 1).tdr_str # nil is ignored
      assert_equal str, @df.drop(Arrow::Array.new([2, 3, 1])).tdr_str # else clause in _parse_element

      assert_raise(DataFrameArgumentError) { @df.drop((:c..:d).each, 1) }
    end
  end

  sub_test_case 'rename' do
    test 'Empty dataframe' do
      df = DataFrame.new
      assert_true df.rename.empty?
      assert_raise(DataFrameArgumentError) { df.rename(:key) }
    end

    test 'rename nothing' do
      assert_true @df2.equal?(@df2.rename)
      assert_true @df2.equal?(@df2.rename([]))
      assert_true @df2.equal?(@df2.rename(nil))
      assert_true @df2.equal?(@df2.rename({}))
      assert_true @df2.equal?(@df2.rename { {} })
      assert_true @df2.equal?(@df2.rename { nil })
      unchanged_key_pair = @df2.keys.each_with_object({}) { |k, h| h[k] = k }
      assert_true @df2.equal?(@df2.rename(unchanged_key_pair))
    end

    test 'rename by arguments' do
      assert_raise(DataFrameArgumentError) { @df2.rename(:key) { :block } }
      assert_raise(DataFrameArgumentError) { @df2.rename(:key) }

      str = <<~OUTPUT
        RedAmber::DataFrame : 5 x 4 Vectors
        Vectors : 2 numeric, 1 string, 1 boolean
        # key      type    level data_preview
        0 :integer uint8       5 [0, 1, 2, 3, nil], 1 nil
        1 :float   double      5 [0.0, 1.1, 2.2, NaN, nil], 1 NaN, 1 nil
        2 :string  string      5 ["A", "B", "C", "D", nil], 1 nil
        3 :bool    boolean     3 {true=>2, false=>2, nil=>1}
      OUTPUT
      assert_equal str, @df2.rename(:index, :integer).tdr_str
      assert_equal str, @df2.rename({ index: :integer }).tdr_str
    end

    test 'rename by block' do
      assert_raise(DataFrameArgumentError) { @df2.rename { :key } }
      assert_raise(DataFrameArgumentError) { @df2.rename { { key_not_exist: :new_key } } }

      str = <<~OUTPUT
        RedAmber::DataFrame : 5 x 4 Vectors
        Vectors : 2 numeric, 1 string, 1 boolean
        # key      type    level data_preview
        0 :integer uint8       5 [0, 1, 2, 3, nil], 1 nil
        1 :float   double      5 [0.0, 1.1, 2.2, NaN, nil], 1 NaN, 1 nil
        2 :string  string      5 ["A", "B", "C", "D", nil], 1 nil
        3 :bool    boolean     3 {true=>2, false=>2, nil=>1}
      OUTPUT
      assert_equal str, @df2.rename {
        { keys.detect { |key| self[key].type == :uint8 } => :integer }
      }.tdr_str
    end

    test 'rename with array' do
      str = <<~OUTPUT
        RedAmber::DataFrame : 5 x 4 Vectors
        Vectors : 2 numeric, 1 string, 1 boolean
        # key      type    level data_preview
        0 :integer uint8       5 [0, 1, 2, 3, nil], 1 nil
        1 :float   double      5 [0.0, 1.1, 2.2, NaN, nil], 1 NaN, 1 nil
        2 :string  string      5 ["A", "B", "C", "D", nil], 1 nil
        3 :bool    boolean     3 {true=>2, false=>2, nil=>1}
      OUTPUT
      assert_equal str, @df2.rename(%i[index integer]).tdr_str
      assert_equal str, @df2.rename { %i[index integer] }.tdr_str

      str2 = <<~OUTPUT
        RedAmber::DataFrame : 5 x 4 Vectors
        Vectors : 2 numeric, 1 string, 1 boolean
        # key      type    level data_preview
        0 :integer uint8       5 [0, 1, 2, 3, nil], 1 nil
        1 :double  double      5 [0.0, 1.1, 2.2, NaN, nil], 1 NaN, 1 nil
        2 :string  string      5 ["A", "B", "C", "D", nil], 1 nil
        3 :bool    boolean     3 {true=>2, false=>2, nil=>1}
      OUTPUT
      assert_equal str2, @df2.rename(%i[index integer], %i[float double]).tdr_str
      assert_equal str2, @df2.rename([%i[index integer], %i[float double]]).tdr_str
      assert_equal str2, @df2.rename { [%i[index integer], %i[float double]] }.tdr_str
    end

    test 'rename blank key' do
      df = DataFrame.new('' => [1, 2, 3], 'A' => [4, 5, 6])
      str = <<~OUTPUT
        RedAmber::DataFrame : 3 x 2 Vectors
        Vectors : 2 numeric
        # key    type  level data_preview
        0 :blank uint8     3 [1, 2, 3]
        1 :A     uint8     3 [4, 5, 6]
      OUTPUT
      assert_equal str, df.rename(:unnamed1, :blank).tdr_str
      assert_equal str, df.rename(unnamed1: :blank).tdr_str
    end
  end

  sub_test_case 'assign' do
    test 'Empty dataframe' do
      df = DataFrame.new
      assert_true df.assign.empty?
      assert_raise(DataFrameArgumentError) { df.assign(:key) } # Causes error for key only
      assert_equal <<~OUTPUT, df.assign(key: []).tdr_str # You can add vector with size zero to empty dataframe
        RedAmber::DataFrame : 0 x 1 Vector
        Vector : 1 string
        # key  type   level data_preview
        0 :key string     0 []
      OUTPUT
    end

    test 'assigner size mismatch' do
      assert_raise(DataFrameArgumentError) { @df2.assign(string: %w[a b c d]) }
      assert_raise(DataFrameArgumentError) { @df2.assign(append: %w[a b c d]) }
    end

    test 'assign_nothing' do
      assert_true @df2.equal?(@df2.assign)
      assert_true @df2.equal?(@df2.assign(nil))
      assert_true @df2.equal?(@df2.assign([]))
      assert_true @df2.equal?(@df2.assign({}))
      assert_true @df2.equal?(@df2.assign {}) # rubocop:ignore Lint/EmptyBlock
      assert_true @df2.equal?(@df2.assign { nil })
      assert_true @df2.equal?(@df2.assign { {} })
      assert_true @df2.equal?(@df2.assign { [] })
    end

    test 'assign by arguments' do
      assert_raise(DataFrameArgumentError) { @df2.assign(:key) } # key only

      unchanged_pair = @df2.keys.each_with_object({}) { |k, h| h[k] = @df2[k].to_a }
      assert_equal @df2.tdr_str, @df2.assign(unchanged_pair).tdr_str

      assigner = { new: %w[a a b b c] }
      assigner_vector = { new: Vector.new(assigner[:new]) }
      str = <<~OUTPUT
        RedAmber::DataFrame : 5 x 5 Vectors
        Vectors : 2 numeric, 2 strings, 1 boolean
        # key     type    level data_preview
        0 :index  uint8       5 [0, 1, 2, 3, nil], 1 nil
        1 :float  double      5 [0.0, 1.1, 2.2, NaN, nil], 1 NaN, 1 nil
        2 :string string      5 ["A", "B", "C", "D", nil], 1 nil
        3 :bool   boolean     3 {true=>2, false=>2, nil=>1}
        4 :new    string      3 {"a"=>2, "b"=>2, "c"=>1}
      OUTPUT
      assert_equal str, @df2.assign(assigner).tdr_str
      assert_equal str, @df2.assign(:new, %w[a a b b c]).tdr_str # directly write assigner
      assert_equal str, @df2.assign(new: %w[a a b b c]).tdr_str # write assigner by hash
      assert_equal str, @df2.assign(assigner.to_a).tdr_str
      assert_equal str, @df2.assign(*assigner.to_a).tdr_str # assign(:x, ary) style
      assert_equal str, @df2.assign(assigner_vector).tdr_str

      assigner2 = { index: [-1, -2, -3, -4, -5], new: %w[a a b b c] }
      str2 = <<~OUTPUT
        RedAmber::DataFrame : 5 x 5 Vectors
        Vectors : 2 numeric, 2 strings, 1 boolean
        # key     type    level data_preview
        0 :index  int8        5 [-1, -2, -3, -4, -5]
        1 :float  double      5 [0.0, 1.1, 2.2, NaN, nil], 1 NaN, 1 nil
        2 :string string      5 ["A", "B", "C", "D", nil], 1 nil
        3 :bool   boolean     3 {true=>2, false=>2, nil=>1}
        4 :new    string      3 {"a"=>2, "b"=>2, "c"=>1}
      OUTPUT
      assert_equal str2, @df2.assign(assigner2).tdr_str
      assert_equal str2, @df2.assign(assigner2.to_a).tdr_str
      assert_equal str2, @df2.assign(*assigner2.to_a).tdr_str # assign([:x, ary1], [:y, ary2]) style
    end

    test 'assign by block' do
      assert_raise(DataFrameArgumentError) { @df2.assign { :key } } # key only

      assigner = { new: %w[a a b b c] }
      str = <<~OUTPUT
        RedAmber::DataFrame : 5 x 5 Vectors
        Vectors : 2 numeric, 2 strings, 1 boolean
        # key     type    level data_preview
        0 :index  uint8       5 [0, 1, 2, 3, nil], 1 nil
        1 :float  double      5 [0.0, 1.1, 2.2, NaN, nil], 1 NaN, 1 nil
        2 :string string      5 ["A", "B", "C", "D", nil], 1 nil
        3 :bool   boolean     3 {true=>2, false=>2, nil=>1}
        4 :new    string      3 {"a"=>2, "b"=>2, "c"=>1}
      OUTPUT
      assert_equal str, @df2.assign { assigner }.tdr_str
      assert_equal str, @df2.assign { assigner.to_a }.tdr_str

      assigner2 = { index: [-1, -2, -3, -4, -5], new: %w[a a b b c] }
      str2 = <<~OUTPUT
        RedAmber::DataFrame : 5 x 5 Vectors
        Vectors : 2 numeric, 2 strings, 1 boolean
        # key     type    level data_preview
        0 :index  int8        5 [-1, -2, -3, -4, -5]
        1 :float  double      5 [0.0, 1.1, 2.2, NaN, nil], 1 NaN, 1 nil
        2 :string string      5 ["A", "B", "C", "D", nil], 1 nil
        3 :bool   boolean     3 {true=>2, false=>2, nil=>1}
        4 :new    string      3 {"a"=>2, "b"=>2, "c"=>1}
      OUTPUT
      assert_equal str2, @df2.assign { assigner2 }.tdr_str
      assert_equal str2, @df2.assign { assigner2.to_a }.tdr_str
    end

    sub_test_case 'Dataframe with zero n_records' do
      test 'assign by block' do
        str = <<~STR
          RedAmber::DataFrame : 0 x 4 Vectors
          Vectors : 2 numeric, 1 string, 1 boolean
          # key type    level data_preview
          0 :a  uint8       0 []
          1 :b  double      0 []
          2 :c  string      0 []
          3 :d  boolean     0 []
        STR
        assert_equal str, @df.filter(@df.c == "nonexistent").assign(:b) { b.multiply(1) }.tdr_str
      end
    end

    test 'assign by both args and block' do
      assert_raise(DataFrameArgumentError) { @df2.assign(:key) {} } # rubocop:disable Lint/EmptyBlock

      str = <<~STR
        RedAmber::DataFrame : 5 x 5 Vectors
        Vectors : 2 numeric, 2 strings, 1 boolean
        # key     type    level data_preview
        0 :index  uint8       5 [0, 1, 2, 3, nil], 1 nil
        1 :float  double      5 [0.0, 1.1, 2.2, NaN, nil], 1 NaN, 1 nil
        2 :string string      5 ["A", "B", "C", "D", nil], 1 nil
        3 :bool   boolean     3 {true=>2, false=>2, nil=>1}
        4 :new    string      3 {"a"=>2, "b"=>2, "c"=>1}
      STR
      assert_equal str, @df2.assign(:new) { %w[a a b b c] }.tdr_str

      str2 = <<~STR
        RedAmber::DataFrame : 5 x 5 Vectors
        Vectors : 2 numeric, 2 strings, 1 boolean
        # key     type    level data_preview
        0 :index  int8        5 [-1, -2, -3, -4, -5]
        1 :float  double      5 [0.0, 1.1, 2.2, NaN, nil], 1 NaN, 1 nil
        2 :string string      5 ["A", "B", "C", "D", nil], 1 nil
        3 :bool   boolean     3 {true=>2, false=>2, nil=>1}
        4 :new    string      3 {"a"=>2, "b"=>2, "c"=>1}
      STR
      assert_equal str2, @df2.assign(:index, :new) { [[-1, -2, -3, -4, -5], %w[a a b b c]] }.tdr_str
      assert_equal str2, @df2.assign(:index, :new) { [Vector.new([-1, -2, -3, -4, -5]), %w[a a b b c]] }.tdr_str
    end

    test 'assign_left by param' do
      assigner = { index: [-1, -2, -3, -4, -5], new: %w[a a b b c] }
      assert_equal <<~OUTPUT, @df2.assign_left(assigner).tdr_str
        RedAmber::DataFrame : 5 x 5 Vectors
        Vectors : 2 numeric, 2 strings, 1 boolean
        # key     type    level data_preview
        0 :new    string      3 {"a"=>2, "b"=>2, "c"=>1}
        1 :index  int8        5 [-1, -2, -3, -4, -5]
        2 :float  double      5 [0.0, 1.1, 2.2, NaN, nil], 1 NaN, 1 nil
        3 :string string      5 ["A", "B", "C", "D", nil], 1 nil
        4 :bool   boolean     3 {true=>2, false=>2, nil=>1}
      OUTPUT
    end

    test 'assign_left by block' do
      assigner = { index: [-1, -2, -3, -4, -5], new: %w[a a b b c] }
      assert_equal <<~OUTPUT, @df2.assign_left { assigner }.tdr_str
        RedAmber::DataFrame : 5 x 5 Vectors
        Vectors : 2 numeric, 2 strings, 1 boolean
        # key     type    level data_preview
        0 :new    string      3 {"a"=>2, "b"=>2, "c"=>1}
        1 :index  int8        5 [-1, -2, -3, -4, -5]
        2 :float  double      5 [0.0, 1.1, 2.2, NaN, nil], 1 NaN, 1 nil
        3 :string string      5 ["A", "B", "C", "D", nil], 1 nil
        4 :bool   boolean     3 {true=>2, false=>2, nil=>1}
      OUTPUT
    end
  end
end
