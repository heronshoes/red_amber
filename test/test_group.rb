# frozen_string_literal: true

require 'test_helper'

class GroupTest < Test::Unit::TestCase
  include RedAmber
  include TestHelper

  sub_test_case 'group' do
    test 'Empty dataframe' do
      df = DataFrame.new
      assert_raise(GroupArgumentError) { df.group(:x).count }
    end

    setup do
      @df = DataFrame.new(
        i: [0, 0, 1, 2, 2, nil],
        f: [0.0, 1.1, 2.2, 3.3, Float::NAN, nil],
        s: ['A', 'B', nil, 'A', 'B', 'A'],
        b: [true, false, true, false, true, nil]
      )
    end

    test 'group all' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 2 Vectors
        Vectors : 1 string, 1 boolean
        # key       type    level data_preview
        0 :s        string      3 ["A", "B", nil], 1 nil
        1 :"all(b)" boolean     2 [false, false, true]
      STR
      assert_equal str, @df.group(:s).all.tdr_str(tally: 0)
    end

    test 'group any' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 2 Vectors
        Vectors : 1 string, 1 boolean
        # key       type    level data_preview
        0 :s        string      3 ["A", "B", nil], 1 nil
        1 :"any(b)" boolean     1 [true, true, true]
      STR
      assert_equal str, @df.group(:s).any.tdr_str(tally: 0)
    end

    test 'group count' do
      str = <<~STR
        RedAmber::DataFrame : 4 x 5 Vectors
        Vectors : 5 numeric
        # key         type  level data_preview
        0 :i          uint8     4 [0, 1, 2, nil], 1 nil
        1 :"count(i)" int64     3 [2, 1, 2, 0]
        2 :"count(f)" int64     3 [2, 1, 2, 0]
        3 :"count(s)" int64     3 [2, 0, 2, 1]
        4 :"count(b)" int64     3 [2, 1, 2, 0]
      STR
      assert_equal str, @df.group(:i).count(%i[i f s b]).tdr_str(tally: 0)
    end

    test 'group count unification' do
      str = <<~STR
        RedAmber::DataFrame : 4 x 2 Vectors
        Vectors : 2 numeric
        # key    type  level data_preview
        0 :i     uint8     4 [0, 1, 2, nil], 1 nil
        1 :count int64     3 [2, 1, 2, 0]
      STR
      df = @df.pick(:i, :f, :b)
      assert_equal str, df.group(:i).count.tdr_str(tally: 0)
    end

    test 'group group_count' do
      str = <<~STR
        RedAmber::DataFrame : 4 x 2 Vectors
        Vectors : 2 numeric
        # key          type  level data_preview
        0 :i           uint8     4 [0, 1, 2, nil], 1 nil
        1 :group_count int64     2 {2=>2, 1=>2}
      STR
      assert_equal str, @df.group(:i).group_count.tdr_str
      assert_equal str, @df.group(:i).count_all.tdr_str
    end

    test 'group group_count w/o nil' do
      dataframe = DataFrame.new(x: %w[A A B B B C])
      group = Group.new(dataframe, :x)
      str = <<~STR
        RedAmber::DataFrame : 3 x 2 Vectors
        Vectors : 1 numeric, 1 string
        # key          type   level data_preview
        0 :x           string     3 ["A", "B", "C"]
        1 :group_count int64      3 [2, 3, 1]
      STR
      assert_equal str, group.group_count.tdr_str
      assert_equal str, group.count_all.tdr_str
    end

    test 'group count_uniq' do
      assert_equal <<~STR, @df.group(:s).count_uniq.tdr_str(tally: 0)
        RedAmber::DataFrame : 3 x 3 Vectors
        Vectors : 2 numeric, 1 string
        # key              type   level data_preview
        0 :s               string     3 ["A", "B", nil], 1 nil
        1 :"count_uniq(i)" int64      2 [2, 2, 1]
        2 :"count_uniq(f)" int64      2 [2, 2, 1]
      STR
    end

    test 'group count with multiple keys and aggregation' do
      str = <<~STR
        RedAmber::DataFrame : 6 x 3 Vectors
        Vectors : 2 numeric, 1 string
        # key    type   level data_preview
        0 :i     uint8      4 [0, 0, 1, 2, 2, ... ], 1 nil
        1 :s     string     3 ["A", "B", nil, "A", "B", ... ], 1 nil
        2 :count int64      2 [1, 1, 1, 1, 1, ... ]
      STR
      assert_equal str, @df.group(:i, :s).count.tdr_str(tally: 0)
    end

    test 'group max' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 5 Vectors
        Vectors : 2 numeric, 1 string, 2 boolean
        # key       type    level data_preview
        0 :b        boolean     3 [true, false, nil], 1 nil
        1 :"max(i)" uint8       2 [2, 2, nil], 1 nil
        2 :"max(f)" double      3 [2.2, 3.3, nil], 1 nil
        3 :"max(s)" string      2 ["B", "B", "A"]
        4 :"max(b)" boolean     3 [true, false, nil], 1 nil
      STR
      assert_equal str, @df.group(:b).max(%i[i f s b]).tdr_str(tally: 0)
    end

    test 'group mean' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 4 Vectors
        Vectors : 3 numeric, 1 boolean
        # key        type    level data_preview
        0 :b         boolean     3 [true, false, nil], 1 nil
        1 :"mean(i)" double      2 [1.0, 1.0, nil], 1 nil
        2 :"mean(f)" double      3 [NaN, 2.2, nil], 1 NaN, 1 nil
        3 :"mean(b)" double      3 [1.0, 0.0, nil], 1 nil
      STR
      assert_equal str, @df.group(:b).mean(%i[i f b]).tdr_str(tally: 0)
    end

    test 'group median' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 3 Vectors
        Vectors : 2 numeric, 1 string
        # key          type   level data_preview
        0 :s           string     3 ["A", "B", nil], 1 nil
        1 :"median(i)" double     2 [0.0, 0.0, 1.0]
        2 :"median(f)" double     3 [0.0, 1.1, 2.2]
      STR
      assert_equal str, @df.group(:s).median.tdr_str(tally: 0)
    end

    test 'group min' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 5 Vectors
        Vectors : 2 numeric, 1 string, 2 boolean
        # key       type    level data_preview
        0 :b        boolean     3 [true, false, nil], 1 nil
        1 :"min(i)" uint8       2 [0, 0, nil], 1 nil
        2 :"min(f)" double      3 [0.0, 1.1, nil], 1 nil
        3 :"min(s)" string      1 ["A", "A", "A"]
        4 :"min(b)" boolean     3 [true, false, nil], 1 nil
      STR
      assert_equal str, @df.group(:b).min(%i[i f s b]).tdr_str(tally: 0)
    end

    test 'group one' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 3 Vectors
        Vectors : 2 numeric, 1 string
        # key       type   level data_preview
        0 :s        string     3 ["A", "B", nil], 1 nil
        1 :"one(i)" uint8      2 [0, 0, 1]
        2 :"one(f)" double     3 [0.0, 1.1, 2.2]
      STR
      assert_equal str, @df.group(:s).one.tdr_str(tally: 0)
    end

    test 'group product' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 4 Vectors
        Vectors : 3 numeric, 1 boolean
        # key           type    level data_preview
        0 :b            boolean     3 [true, false, nil], 1 nil
        1 :"product(i)" uint64      2 [0, 0, nil], 1 nil
        2 :"product(f)" double      3 [NaN, 3.63, nil], 1 NaN, 1 nil
        3 :"product(b)" uint64      3 [1, 0, nil], 1 nil
      STR
      assert_equal str, @df.group(:b).product(%i[i f b]).tdr_str(tally: 0)
    end

    test 'group stddev' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 3 Vectors
        Vectors : 2 numeric, 1 boolean
        # key          type    level data_preview
        0 :b           boolean     3 [true, false, nil], 1 nil
        1 :"stddev(i)" double      3 [0.816496580927726, 1.0, nil], 1 nil
        2 :"stddev(f)" double      3 [NaN, 1.0999999999999999, nil], 1 NaN, 1 nil
      STR
      assert_equal str, @df.group(:b).stddev(%i[i f]).tdr_str(tally: 0)
    end

    test 'group sum' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 4 Vectors
        Vectors : 3 numeric, 1 boolean
        # key       type    level data_preview
        0 :b        boolean     3 [true, false, nil], 1 nil
        1 :"sum(i)" uint64      3 [3, 2, nil], 1 nil
        2 :"sum(f)" double      3 [NaN, 4.4, nil], 1 NaN, 1 nil
        3 :"sum(b)" uint64      3 [3, 0, nil], 1 nil
      STR
      assert_equal str, @df.group(:b).sum(%i[i f b]).tdr_str(tally: 0)
    end

    test 'group variance' do
      str = <<~STR
        RedAmber::DataFrame : 3 x 3 Vectors
        Vectors : 2 numeric, 1 boolean
        # key            type    level data_preview
        0 :b             boolean     3 [true, false, nil], 1 nil
        1 :"variance(i)" double      3 [0.6666666666666666, 1.0, nil], 1 nil
        2 :"variance(f)" double      3 [NaN, 1.2099999999999997, nil], 1 NaN, 1 nil
      STR
      assert_equal str, @df.group(:b).variance(%i[i f]).tdr_str(tally: 0)
    end

    test 'group with a block' do
      assert_raise(GroupArgumentError) { @df.group(:i) {} }

      str = <<~STR
        RedAmber::DataFrame : 4 x 2 Vectors
        Vectors : 2 numeric
        # key    type  level data_preview
        0 :i     uint8     4 [0, 1, 2, nil], 1 nil
        1 :count int64     3 [2, 1, 2, 0]
      STR
      assert_equal str, @df.group(:i) { count(:i, :f, :b) }.tdr_str(tally: 0)

      str = <<~STR
        RedAmber::DataFrame : 4 x 3 Vectors
        Vectors : 3 numeric
        # key       type   level data_preview
        0 :i        uint8      4 [0, 1, 2, nil], 1 nil
        1 :count    int64      3 [2, 1, 2, 0]
        2 :"sum(f)" double     4 [1.1, 2.2, NaN, nil], 1 NaN, 1 nil
      STR
      assert_equal str, @df.group(:i) { [count(:i, :f, :b), sum] }.tdr_str(tally: 0)
    end

    test 'count with not a key of self' do
      assert_raise(GroupArgumentError) { @df.group(:i).count(:x) }
      assert_raise(GroupArgumentError) { @df.group(:i).count(:i, :x) }
    end
  end

  sub_test_case('group by filters') do
    setup do
      @df = DataFrame.new(
        i: [0, 0, 1, 2, 2, nil],
        f: [0.0, 1.1, 2.2, 3.3, Float::NAN, nil],
        s: ['A', 'B', nil, 'A', 'B', 'A'],
        b: [true, false, true, false, true, nil]
      )
    end

    test 'filters by a key' do
      expect = [
        [true,  false, false, false, false, nil],
        [false, true,  false, false, false, nil],
        [false, false, false, true,  false, nil],
        [false, false, true,  false, false, nil],
        [false, false, false, false, true,  nil],
        [false, false, false, false, false, true],
      ]
      assert_equal expect, @df.group(:f).filters.map(&:to_a)
      assert_true @df.group(:f).filters.all?(Vector)
    end

    test 'filters by multiple keys' do
      expect = [
        [true, false, false, false, false, nil],
        [false, true, false, false, false, false],
        [false, false, true, false, false, false],
        [false, false, false, true, false, nil],
        [false, false, false, false, true, false],
        [false, false, false, false, false, true],
      ]
      assert_equal expect, @df.group(:i, :s).filters.map(&:to_a)
      assert_true @df.group(:i, :s).filters.all?(Vector)
    end

    test 'each' do
      assert_true @df.group(:i).each.is_a?(Enumerator)
      expect = <<~STR
        RedAmber::DataFrame : 2 x 4 Vectors
        Vectors : 2 numeric, 1 string, 1 boolean
        # key type    level data_preview
        0 :i  uint8       1 {0=>2}
        1 :f  double      2 [0.0, 1.1]
        2 :s  string      2 ["A", "B"]
        3 :b  boolean     2 [true, false]
        RedAmber::DataFrame : 1 x 4 Vectors
        Vectors : 2 numeric, 1 string, 1 boolean
        # key type    level data_preview
        0 :i  uint8       1 [1]
        1 :f  double      1 [2.2]
        2 :s  string      1 [nil], 1 nil
        3 :b  boolean     1 [true]
        RedAmber::DataFrame : 2 x 4 Vectors
        Vectors : 2 numeric, 1 string, 1 boolean
        # key type    level data_preview
        0 :i  uint8       1 {2=>2}
        1 :f  double      2 [3.3, NaN], 1 NaN
        2 :s  string      2 ["A", "B"]
        3 :b  boolean     2 [false, true]
        RedAmber::DataFrame : 1 x 4 Vectors
        Vectors : 2 numeric, 1 string, 1 boolean
        # key type    level data_preview
        0 :i  uint8       1 [nil], 1 nil
        1 :f  double      1 [nil], 1 nil
        2 :s  string      1 ["A"]
        3 :b  boolean     1 [nil], 1 nil
      STR
      assert_equal expect,
                   @df.group(:i).each.with_object(StringIO.new) { |df, accum| accum << df.tdr_str }.string
    end

    test 'inspect' do
      group = @df.group(:i)
      str = <<~STR
        #<RedAmber::Group : #{format('0x%016x', group.object_id)}>
                i group_count
          <uint8>     <int64>
        0       0           2
        1       1           1
        2       2           2
        3   (nil)           1
      STR
      assert_equal str, group.inspect
    end

    test 'summarize { func(key) }' do
      group = @df.group(:s)
      str = <<~STR
        RedAmber::DataFrame : 3 x 2 Vectors
        Vectors : 1 numeric, 1 string
        # key       type   level data_preview
        0 :s        string     3 ["A", "B", nil], 1 nil
        1 :"sum(f)" double     3 [3.3, NaN, 2.2], 1 NaN
      STR
      assert_equal str, group.summarize { sum(:f) }.tdr_str
    end

    test 'summarize { Array }' do
      group = @df.group(:s)
      str = <<~STR
        RedAmber::DataFrame : 3 x 4 Vectors
        Vectors : 3 numeric, 1 string
        # key       type   level data_preview
        0 :s        string     3 ["A", "B", nil], 1 nil
        1 :"sum(i)" uint64     2 [2, 2, 1]
        2 :"sum(f)" double     3 [3.3, NaN, 2.2], 1 NaN
        3 :count    uint8      2 [2, 2, 1]
      STR
      assert_equal str, group.summarize { [sum, count] }.tdr_str(tally: 0)
    end

    test 'summarize { Hash }' do
      group = @df.group(:s)
      str = <<~STR
        RedAmber::DataFrame : 3 x 4 Vectors
        Vectors : 3 numeric, 1 string
        # key    type   level data_preview
        0 :s     string     3 ["A", "B", nil], 1 nil
        1 :sum_i uint8      2 [2, 2, 1]
        2 :sum_f double     3 [3.3, NaN, 2.2], 1 NaN
        3 :count uint8      2 [2, 2, 1]
      STR
      assert_equal str, group.summarize {
                          { sum_i: sum(:i), sum_f: sum(:f), count: count }
                        }.tdr_str(tally: 0)
    end

    test 'summarize(arg) { arg }' do
      group = @df.group(:s)
      str = <<~STR
        RedAmber::DataFrame : 3 x 2 Vectors
        Vectors : 1 numeric, 1 string
        # key    type   level data_preview
        0 :s     string     3 ["A", "B", nil], 1 nil
        1 :sum_i uint8      2 [2, 2, 1]
      STR
      assert_equal str, group.summarize(:sum_i) {
                          sum(:i)
                        }.tdr_str(tally: 0)
      assert_equal str, group.summarize(:sum_i) {
                          [sum(:i)]
                        }.tdr_str(tally: 0)
    end

    test 'summarize(args) { args }' do
      group = @df.group(:s)
      str = <<~STR
        RedAmber::DataFrame : 3 x 3 Vectors
        Vectors : 2 numeric, 1 string
        # key    type   level data_preview
        0 :s     string     3 ["A", "B", nil], 1 nil
        1 :sum_i uint8      2 [2, 2, 1]
        2 :sum_f double     3 [3.3, NaN, 2.2], 1 NaN
      STR
      assert_equal str, group.summarize(:sum_i, :sum_f) {
                          [sum(:i), sum(:f)]
                        }.tdr_str(tally: 0)
    end

    test 'summarize(args)' do
      group = @df.group(:s)
      str = <<~STR
        RedAmber::DataFrame : 3 x 3 Vectors
        Vectors : 2 numeric, 1 string
        # key       type   level data_preview
        0 :s        string     3 ["A", "B", nil], 1 nil
        1 :"sum(i)" uint64     2 [2, 2, 1]
        2 :"sum(f)" double     3 [3.3, NaN, 2.2], 1 NaN
      STR
      assert_equal str, group.summarize(group.sum).tdr_str(tally: 0)
    end

    test 'summarize { not_one_aggregation_in_Hash }' do
      group = @df.group(:s)
      assert_raise(GroupArgumentError) { group.summarize { { sum: sum } } }
    end
  end

  sub_test_case '#grouped_frame' do
    setup do
      @df = DataFrame.new(
        i: [0, 0, 1, 2, 2, nil],
        f: [0.0, 1.1, 2.2, 3.3, Float::NAN, nil],
        s: ['A', 'B', nil, 'A', 'B', 'A'],
        b: [true, false, true, false, true, nil]
      )
    end

    test '#grouped_frame' do
      group = @df.group(:s)
      str = <<~STR
        RedAmber::DataFrame : 3 x 1 Vector
        Vector : 1 string
        # key type   level data_preview
        0 :s  string     3 ["A", "B", nil], 1 nil
      STR
      assert_equal str, group.grouped_frame.tdr_str
    end
  end

  sub_test_case 'call Vector\'s aggregating function' do
    setup do
      @df = DataFrame.new(
        i: [0, 0, 1, 2, 2, 2],
        f: [0.0, 1.1, 2.2, 3.3, 4.4, 5.5]
      )
    end

    test 'filters by a key' do
      expect = [
        [:'sum(f)'],
        [[1.1, 2.2, 13.2]],
      ]
      assert_equal expect, @df.group(:i).agg_sum(:f)
    end
  end
end
