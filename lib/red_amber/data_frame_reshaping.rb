# frozen_string_literal: true

module RedAmber
  # Mix-in for the class DataFrame
  module DataFrameReshaping
    # Create a transposed DataFrame for the wide (may be messy) DataFrame.
    #
    # @param key [Symbol]
    #   key of the index column
    #   to transepose into keys.
    #   If it is not specified, keys[0] is used.
    # @param name [Symbol]
    #   key name of transposed index column.
    #   If it is not specified, :NAME is used.
    #   If it already exists, :NAME1 or :NAME1.succ is used.
    # @return [DataFrame]
    #   trnsposed DataFrame
    #
    # @example Transpose a DataFrame without options
    #
    #   import_cars
    #
    #   # =>
    #   #<RedAmber::DataFrame : 5 x 6 Vectors, 0x000000000000d520>
    #        Year    Audi     BMW BMW_MINI Mercedes-Benz      VW
    #     <int64> <int64> <int64>  <int64>       <int64> <int64>
    #   0    2017   28336   52527    25427         68221   49040
    #   1    2018   26473   50982    25984         67554   51961
    #   2    2019   24222   46814    23813         66553   46794
    #   3    2020   22304   35712    20196         57041   36576
    #   4    2021   22535   35905    18211         51722   35215
    #
    #   import_cars.transpose
    #
    #   # =>
    #   #<RedAmber::DataFrame : 5 x 6 Vectors, 0x0000000000010a2c>
    #     NAME              2017     2018     2019     2020     2021
    #     <string>      <uint32> <uint32> <uint32> <uint16> <uint16>
    #   0 Audi             28336    26473    24222    22304    22535
    #   1 BMW              52527    50982    46814    35712    35905
    #   2 BMW_MINI         25427    25984    23813    20196    18211
    #   3 Mercedes-Benz    68221    67554    66553    57041    51722
    #   4 VW               49040    51961    46794    36576    35215
    #
    #   The leftmost column is created by original keys and
    #   `:NAME` is automatically used for the column name.
    #
    # @example Transpose a DataFrame with `:name` option
    #
    #   import_cars.transpose(name: :Manufacturer)
    #
    #   # =>
    #   #<RedAmber::DataFrame : 5 x 6 Vectors, 0x0000000000010a2c>
    #     Manufacturer      2017     2018     2019     2020     2021
    #     <string>      <uint32> <uint32> <uint32> <uint16> <uint16>
    #   0 Audi             28336    26473    24222    22304    22535
    #   1 BMW              52527    50982    46814    35712    35905
    #   2 BMW_MINI         25427    25984    23813    20196    18211
    #   3 Mercedes-Benz    68221    67554    66553    57041    51722
    #   4 VW               49040    51961    46794    36576    35215
    #
    #   `:name` option can specify column name.
    #
    # @example Transpose a DataFrame by the :key in the middle of the DataFrame
    #
    #   import_cars_middle = import_cars.pick(1..2, 0, 3..)
    #
    #   # =>
    #   #<RedAmber::DataFrame : 5 x 6 Vectors, 0x000000000000f244>
    #        Audi     BMW    Year BMW_MINI Mercedes-Benz      VW
    #     <int64> <int64> <int64>  <int64>       <int64> <int64>
    #   0   28336   52527    2017    25427         68221   49040
    #   1   26473   50982    2018    25984         67554   51961
    #   2   24222   46814    2019    23813         66553   46794
    #   3   22304   35712    2020    20196         57041   36576
    #   4   22535   35905    2021    18211         51722   35215
    #
    #   import_cars_middle.transpose(key: :Year)
    #
    #   # =>
    #   #<RedAmber::DataFrame : 5 x 6 Vectors, 0x0000000000010a2c>
    #     NAME              2017     2018     2019     2020     2021
    #     <string>      <uint32> <uint32> <uint32> <uint16> <uint16>
    #   0 Audi             28336    26473    24222    22304    22535
    #   1 BMW              52527    50982    46814    35712    35905
    #   2 BMW_MINI         25427    25984    23813    20196    18211
    #   3 Mercedes-Benz    68221    67554    66553    57041    51722
    #   4 VW               49040    51961    46794    36576    35215
    #
    # @since 0.2.0
    #
    def transpose(key: keys.first, name: :NAME)
      unless keys.include?(key)
        raise DataFrameArgumentError, "Self does not include: #{key}"
      end

      # Find unused name
      new_keys = self[key].to_a.map { |e| e.to_s.to_sym }
      name = (:NAME1..).find { |k| !new_keys.include?(k) } if new_keys.include?(name)

      names = (keys - [key]).map { |x| x&.to_s }
      hash = { name => names }
      i = keys.index(key)
      each_row do |h|
        k = h.values[i]
        hash[k] = h.values - [k]
      end
      DataFrame.new(hash)
    end

    # Create a 'long' (may be tidy) DataFrame from a 'wide' DataFrame.
    #
    # @param keep_keys [<Symbol>]
    #   keys to keep.
    # @param name [Symbol, String]
    #   a new key name of the column which is come from key names.
    # @param value [Symbol, String]
    #   a new key name of the column which is come from values.
    # @return [DataFrame]
    #   long DataFrame.
    #
    # @example `to_long` without options
    #
    #   import_cars
    #
    #   # =>
    #   #<RedAmber::DataFrame : 5 x 6 Vectors, 0x000000000000d520>
    #        Year    Audi     BMW BMW_MINI Mercedes-Benz      VW
    #     <int64> <int64> <int64>  <int64>       <int64> <int64>
    #   0    2017   28336   52527    25427         68221   49040
    #   1    2018   26473   50982    25984         67554   51961
    #   2    2019   24222   46814    23813         66553   46794
    #   3    2020   22304   35712    20196         57041   36576
    #   4    2021   22535   35905    18211         51722   35215
    #
    #   import_cars.to_long(:Year)
    #
    #   # =>
    #   #<RedAmber::DataFrame : 25 x 3 Vectors, 0x0000000000011864>
    #          Year NAME             VALUE
    #      <uint16> <string>      <uint32>
    #    0     2017 Audi             28336
    #    1     2017 BMW              52527
    #    2     2017 BMW_MINI         25427
    #    3     2017 Mercedes-Benz    68221
    #    4     2017 VW               49040
    #    :        : :                    :
    #   22     2021 BMW_MINI         18211
    #   23     2021 Mercedes-Benz    51722
    #   24     2021 VW               35215
    #
    # @example `to_long` with options `:name` and `:value`
    #
    #   import_cars.to_long(:Year, name: :Manufacturer, value: :Num_of_imported)
    #
    #   # =>
    #   #<RedAmber::DataFrame : 25 x 3 Vectors, 0x000000000001359c>
    #          Year Manufacturer  Num_of_imported
    #      <uint16> <string>             <uint32>
    #    0     2017 Audi                    28336
    #    1     2017 BMW                     52527
    #    2     2017 BMW_MINI                25427
    #    3     2017 Mercedes-Benz           68221
    #    4     2017 VW                      49040
    #    :        : :                           :
    #   22     2021 BMW_MINI                18211
    #   23     2021 Mercedes-Benz           51722
    #   24     2021 VW                      35215
    #
    # @since 0.2.0
    #
    def to_long(*keep_keys, name: :NAME, value: :VALUE)
      warn('[Info] No key to keep is specified.') if keep_keys.empty?

      not_included = keep_keys - keys
      unless not_included.empty?
        raise DataFrameArgumentError, "Not have keys #{not_included}"
      end

      name = name.to_sym
      if keep_keys.include?(name)
        raise DataFrameArgumentError,
              "Can't specify the key: #{name} for the column from keys."
      end

      value = value.to_sym
      if keep_keys.include?(value)
        raise DataFrameArgumentError,
              "Can't specify the key: #{value} for the column from values."
      end

      hash = Hash.new { |h, k| h[k] = [] }
      l = keys.size - keep_keys.size
      each_row do |row|
        row.each do |k, v|
          if keep_keys.include?(k)
            hash[k].concat([v] * l)
          else
            hash[name] << k
            hash[value] << v
          end
        end
      end
      hash[name] = hash[name].map { |x| x&.to_s }
      DataFrame.new(hash)
    end

    # Create a 'wide' (may be messy) DataFrame from a 'long' DataFrame.
    #
    # @param name [Symbol, String]
    #   a new key name of the columnwhich will be expanded to key names.
    # @param value [Symbol, String]
    #   a new key name of the column which will be expanded to values.
    # @return [DataFrame]
    #   wide DataFrame.
    #
    # @example `to_wide` without options
    #
    #   import_cars_long = import_cars.to_long(:Year)
    #
    #   # =>
    #   #<RedAmber::DataFrame : 25 x 3 Vectors, 0x0000000000011864>
    #          Year NAME             VALUE
    #      <uint16> <string>      <uint32>
    #    0     2017 Audi             28336
    #    1     2017 BMW              52527
    #    2     2017 BMW_MINI         25427
    #    3     2017 Mercedes-Benz    68221
    #    4     2017 VW               49040
    #    :        : :                    :
    #   22     2021 BMW_MINI         18211
    #   23     2021 Mercedes-Benz    51722
    #   24     2021 VW               35215
    #
    #   import_cars_long.to_wide
    #   # or same as `import_cars_long.to_wide(name: :NAME, value: VALUE)`
    #
    #   # =>
    #   #<RedAmber::DataFrame : 5 x 6 Vectors, 0x000000000000d520>
    #        Year    Audi     BMW BMW_MINI Mercedes-Benz      VW
    #     <int64> <int64> <int64>  <int64>       <int64> <int64>
    #   0    2017   28336   52527    25427         68221   49040
    #   1    2018   26473   50982    25984         67554   51961
    #   2    2019   24222   46814    23813         66553   46794
    #   3    2020   22304   35712    20196         57041   36576
    #   4    2021   22535   35905    18211         51722   35215
    #
    #   Columns other than `NAME` and `VALUE` (it is `Year` for this case) will be
    #   automatically processed and do not need to specify.
    #
    # @since 0.2.0
    #
    def to_wide(name: :NAME, value: :VALUE, fill_missing: false, fill_with: nil)
      name = name.to_sym
      unless keys.include?(name)
        raise DataFrameArgumentError,
              "You are going to keep the key: #{name}. " \
              'You may need to specify the column name ' \
              'that gives the new keys by `:name` option.'
      end

      value = value.to_sym
      unless keys.include?(value)
        raise DataFrameArgumentError,
              "You are going to keep the key: #{value}. " \
              'You may need to specify the column name ' \
              'that gives the new values by `:value` option.'
      end

      hash = Hash.new { |h, k| h[k] = {} }
      keep_keys = keys - [name, value]
      each_row do |row|
        keeps, converts = row.partition { |k, _| keep_keys.include?(k) }
        h = converts.to_h
        hash[keeps.to_h][h[name].to_s.to_sym] = h[value]
      end
      if fill_missing
        names = [].union(*hash.values.collect(&:keys))
        hash.each_pair do |ns, vs|
          next if vs.length == names.length

          keys = vs.keys
          values = vs.values
          names.each_with_index do |n, i|
            next if vs.key?(n)

            keys.insert(i, n)
            values.insert(i, fill_with)
          end
          hash[ns] = keys.zip(values).to_h
        end
      end
      ks = hash.first[0].keys + hash.first[1].keys
      vs = hash.map { |k, v| k.values + v.values }.transpose
      DataFrame.new(ks.zip(vs))
    end
  end
end
