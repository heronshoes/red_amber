# frozen_string_literal: true

module RedAmber
  # Mix-in for the class DataFrame
  module DataFrameVariableOperation
    # Array is refined
    using RefineArray

    # Select variables (columns) to create a new DataFrame.
    #
    # @note if a single key is specified, DataFrame#pick generates a DataFrame.
    #   On the other hand, DataFrame#[] generates a Vector.
    #
    # @overload pick(keys)
    #   Pick up variables by Symbol(s) or String(s).
    #
    #   @param keys [Symbol, String, <Symbol, String>]
    #     key name(s) of variables to pick.
    #   @return [DataFrame]
    #     picked DataFrame.
    #   @example Pick up by a key
    #     languages
    #
    #     # =>
    #     #<RedAmber::DataFrame : 4 x 3 Vectors, 0x00000000000cfd8c>
    #       Language Creator                         Released
    #       <string> <string>                        <uint16>
    #     0 Ruby     Yukihiro Matsumoto                  1995
    #     1 Python   Guido van Rossum                    1991
    #     2 R        Ross Ihaka and Robert Gentleman     1993
    #     3 Rust     Graydon Hoare                       2001
    #
    #     languages.pick(:Language)
    #
    #     # =>
    #     #<RedAmber::DataFrame : 4 x 1 Vector, 0x0000000000113d20>
    #       Language
    #       <string>
    #     0 Ruby
    #     1 Python
    #     2 R
    #     3 Rust
    #
    #     languages[:Language]
    #
    #     # =>
    #     #<RedAmber::Vector(:string, size=4, chunked):0x000000000010359c>
    #     ["Ruby", "Python", "R", "Rust"]
    #
    # @overload pick(booleans)
    #   Pick up variables by booleans.
    #
    #   @param booleans [<Booleans, nil>, Vector]
    #     boolean array or vecctor to pick up variables at true.
    #   @return [DataFrame]
    #     picked DataFrame.
    #   @example Pick up by booleans
    #     languages.pick(true, true, false)
    #
    #     # =>
    #     #<RedAmber::DataFrame : 4 x 2 Vectors, 0x0000000000066a1c>
    #     Language Creator
    #     <string> <string>
    #     0 Ruby     Yukihiro Matsumoto
    #     1 Python   Guido van Rossum
    #     2 R        Ross Ihaka and Robert Gentleman
    #     3 Rust     Graydon Hoare
    #
    #     is_string = languages.vectors.map(&:string?) # [true, true, false]
    #     languages.pick(is_string)
    #     # =>
    #     (same as above)
    #
    # @overload pick(indices)
    #   Pick up variables by column indices.
    #
    #   @param indices [Integer, Float, Range<Integer>, Vector, Arrow::Array]
    #     numeric array to pick up variables by column index.
    #   @return [DataFrame]
    #     picked DataFrame.
    #   @example Pick up by indices
    #     languages.pick(0, 2, 1)
    #
    #     # =>
    #     #<RedAmber::DataFrame : 4 x 3 Vectors, 0x000000000011cfb0>
    #       Language Released Creator
    #       <string> <uint16> <string>
    #     0 Ruby         1995 Yukihiro Matsumoto
    #     1 Python       1991 Guido van Rossum
    #     2 R            1993 Ross Ihaka and Robert Gentleman
    #     3 Rust         2001 Graydon Hoare
    #
    # @overload pick
    #   Pick up variables by the yielded value from the block.
    #   @note Arguments and a block cannot be used simultaneously.
    #
    #   @yield [self]
    #     the block is called within the context of self.
    #     (Block is called by instance_eval(&block). )
    #   @yieldreturn [keys, booleans, indices]
    #     returns keys, booleans or indices just same as arguments.
    #   @return [DataFrame]
    #     picked DataFrame.
    #   @example Pick up by a block.
    #     # same as languages.pick { |df| df.languages.vectors.map(&:string?) }
    #     languages.pick { languages.vectors.map(&:string?) }
    #
    #     # =>
    #     #<RedAmber::DataFrame : 4 x 2 Vectors, 0x0000000000154104>
    #       Language Creator
    #       <string> <string>
    #     0 Ruby     Yukihiro Matsumoto
    #     1 Python   Guido van Rossum
    #     2 R        Ross Ihaka and Robert Gentleman
    #     3 Rust     Graydon Hoare
    #
    def pick(*args, &block)
      if block
        unless args.empty?
          raise DataFrameArgumentError, 'Must not specify both arguments and block.'
        end

        args = [instance_eval(&block)]
      end

      case args
      in [] | [nil]
        return DataFrame.new
      in [*] if args.symbol?
        return DataFrame.create(@table.select_columns(*args))
      in [*] if args.boolean?
        picker = keys.select_by_booleans(args)
        return DataFrame.create(@table.select_columns(*picker))
      in [(Vector | Arrow::Array | Arrow::ChunkedArray) => a]
        picker = a.to_a
      else
        picker = parse_args(args, n_keys)
      end

      return DataFrame.new if picker.compact.empty?

      if picker.boolean?
        picker = keys.select_by_booleans(picker)
        return DataFrame.create(@table.select_columns(*picker))
      end
      picker.compact!
      raise DataFrameArgumentError, "some keys are duplicated: #{args}" if picker.uniq!

      return self if picker == keys

      DataFrame.create(@table.select_columns(*picker))
    end

    # Drop off some variables (columns) to create a remainer DataFrame.
    #
    # @note DataFrame#drop creates a DataFrame even if it is a single column
    #   (not a Vector).
    #
    # @overload drop(keys)
    #   Drop off variables by Symbol(s) or String(s).
    #
    #   @param keys [Symbol, String, <Symbol, String>]
    #     key name(s) of variables to drop.
    #   @return [DataFrame]
    #     remainer DataFrame.
    #   @example Drop off by a key
    #     languages
    #
    #     # =>
    #     #<RedAmber::DataFrame : 4 x 3 Vectors, 0x00000000000cfd8c>
    #       Language Creator                         Released
    #       <string> <string>                        <uint16>
    #     0 Ruby     Yukihiro Matsumoto                  1995
    #     1 Python   Guido van Rossum                    1991
    #     2 R        Ross Ihaka and Robert Gentleman     1993
    #     3 Rust     Graydon Hoare                       2001
    #
    #     languages.drop(:Language)
    #
    #     # =>
    #     #<RedAmber::DataFrame : 4 x 2 Vectors, 0x000000000005805c>
    #       Creator                         Released
    #       <string>                        <uint16>
    #     0 Yukihiro Matsumoto                  1995
    #     1 Guido van Rossum                    1991
    #     2 Ross Ihaka and Robert Gentleman     1993
    #     3 Graydon Hoare                       2001
    #
    # @overload drop(booleans)
    #   Drop off variables by booleans.
    #
    #   @param booleans [<Booleans, nil>, Vector]
    #     boolean array or vector of variables to drop at true.
    #   @return [DataFrame]
    #     remainer DataFrame.
    #   @example Drop off by booleans
    #     is_numeric = languages.vectors.map(&:numeric?) # [nil, nil, true]
    #     languages.drop(is_numeric)
    #
    #     # =>
    #     #<RedAmber::DataFrame : 4 x 2 Vectors, 0x0000000000066a1c>
    #     Language Creator
    #     <string> <string>
    #     0 Ruby     Yukihiro Matsumoto
    #     1 Python   Guido van Rossum
    #     2 R        Ross Ihaka and Robert Gentleman
    #     3 Rust     Graydon Hoare
    #
    # @overload drop(indices)
    #   Drop off variables by column indices.
    #
    #   @param indices [Integer, Float, Range<Integer>, Vector, Arrow::Array]
    #     numeric array of variables to drop by column index.
    #   @return [DataFrame]
    #     remainer DataFrame.
    #   @example Drop off by indices
    #     languages.drop(2)
    #
    #     # =>
    #     #<RedAmber::DataFrame : 4 x 2 Vectors, 0x0000000000066a1c>
    #     Language Creator
    #     <string> <string>
    #     0 Ruby     Yukihiro Matsumoto
    #     1 Python   Guido van Rossum
    #     2 R        Ross Ihaka and Robert Gentleman
    #     3 Rust     Graydon Hoare
    #
    # @overload drop
    #   Drop off variables by the yielded value from the block.
    #   @note Arguments and a block cannot be used simultaneously.
    #
    #   @yield [self] the block is called within the context of self.
    #     (Block is called by instance_eval(&block). )
    #   @yieldreturn [keys, booleans, indices]
    #     returns keys, booleans or indices just same as arguments.
    #   @return [DataFrame]
    #     remainer DataFrame.
    #   @example Drop off by a block.
    #     # same as languages.drop { |df| df.vectors.map(&:numeric?) }
    #     languages.drop { vectors.map(&:numeric?) }
    #
    #     # =>
    #     #<RedAmber::DataFrame : 4 x 2 Vectors, 0x0000000000154104>
    #       Language Creator
    #       <string> <string>
    #     0 Ruby     Yukihiro Matsumoto
    #     1 Python   Guido van Rossum
    #     2 R        Ross Ihaka and Robert Gentleman
    #     3 Rust     Graydon Hoare
    #
    def drop(*args, &block)
      if block
        unless args.empty?
          raise DataFrameArgumentError, 'Must not specify both arguments and block.'
        end

        args = [instance_eval(&block)]
      end
      return self if args.compact.empty? || empty?

      picker =
        if args.symbol?
          keys - args
        elsif args.boolean?
          keys.reject_by_booleans(args)
        elsif args.integer?
          keys.reject_by_indices(args)
        else
          dropper = parse_args(args, n_keys)
          if dropper.compact.empty?
            return self
          elsif dropper.boolean?
            keys.reject_by_booleans(dropper)
          elsif dropper.symbol?
            keys - dropper
          else
            dropper.compact!
            unless dropper.integer?
              raise DataFrameArgumentError, "Invalid argument #{args}"
            end

            keys.reject_by_indices(dropper)
          end
        end

      return DataFrame.new if picker.empty?

      DataFrame.create(@table.select_columns(*picker))
    end

    # rename keys (variable/column names) to create a updated DataFrame.
    #
    # @overload rename(key_pairs)
    #   Rename by key pairs as a Hash.
    #
    #   @param key_pairs [Hash{existing_key => new_key}]
    #     key pair(s) of existing name and new name.
    #   @return [DataFrame]
    #     renamed DataFrame.
    #   @example Rename by a Hash
    #     comecome
    #
    #     # =>
    #     #<RedAmber::DataFrame : 3 x 2 Vectors, 0x00000000000037b4>
    #       name         age
    #       <string> <uint8>
    #     0 Yasuko        68
    #     1 Rui           49
    #     2 Hinata        28
    #
    #     comecome.rename(:age => :age_in_1993)
    #
    #     # =>
    #     #<RedAmber::DataFrame : 3 x 2 Vectors, 0x00000000000037c8>
    #       name     age_in_1993
    #       <string>     <uint8>
    #     0 Yasuko            68
    #     1 Rui               49
    #     2 Hinata            28
    #
    # @overload rename(key_pairs)
    #   Rename by key pairs as an Array of Array.
    #
    #   @param key_pairs [<Array[existing_key, new_key]>]
    #     key pair(s) of existing name and new name.
    #   @return [DataFrame]
    #     renamed DataFrame.
    #   @example Rename by an Array
    #     renamer = [[:name, :heroine], [:age, :age_in_1993]]
    #     comecome.rename(renamer)
    #
    #     # =>
    #     #<RedAmber::DataFrame : 3 x 2 Vectors, 0x00000000000037dc>
    #       heroine  age_in_1993
    #       <string>     <uint8>
    #     0 Yasuko            68
    #     1 Rui               49
    #     2 Hinata            28
    #
    # @overload rename
    #   Rename by key pairs yielding from block.
    #
    #   @yield [self] the block is called within the context of self.
    #     (Block is called by instance_eval(&block). )
    #   @yieldreturn [<[existing_key, new_key]>, Hash]
    #     returns an Array or a Hash just same as arguments.
    #   @return [DataFrame]
    #     renamed DataFrame.
    #   @example Rename by block.
    #     df
    #
    #     # =>
    #     #<RedAmber::DataFrame : 2 x 3 Vectors, 0x000000000000c29c>
    #             X       Y       Z
    #       <uint8> <uint8> <uint8>
    #     0       1       3       5
    #     1       2       4       6
    #
    #     df.rename { keys.zip(keys.map(&:downcase)) }
    #     # or
    #     df.rename { [keys, keys.map(&:downcase)].transpose }
    #
    #     # =>
    #     #<RedAmber::DataFrame : 2 x 3 Vectors, 0x000000000000c364>
    #             x       y       z
    #       <uint8> <uint8> <uint8>
    #     0       1       3       5
    #     1       2       4       6
    #
    def rename(*renamer, &block)
      if block
        unless renamer.empty?
          raise DataFrameArgumentError, 'Must not specify both arguments and a block'
        end

        renamer = [instance_eval(&block)]
      end
      case renamer
      in [] | [nil] | [{}] | [[]]
        return self
      in [Hash => key_pairs]
      # noop
      in [ (Symbol | String) => from, (Symbol | String) => to]
        key_pairs = { from => to }
      in [Array => array_in_array]
        key_pairs = try_convert_to_hash(array_in_array)
      in [Array, *] => array_in_array1
        key_pairs = try_convert_to_hash(array_in_array1)
      else
        raise DataFrameArgumentError, "Invalid argument #{renamer}"
      end
      rename_by_hash(key_pairs)
    end

    # Assign new or updated variables (columns) and create an updated DataFrame.
    # - Array-like variables with new keys will append new columns from right.
    # - Array-like variables with exisiting keys will update corresponding vectors.
    # - Symbol key and String key are considered as the same key.
    # - If assigner is empty or nil, returns self.
    #
    # @overload assign(key_value_pairs)
    #   accepts pairs of key and values by an Array or a Hash.
    #
    #   @param key_value_pairs [Array<key, array_like>, Hash{key => array_like}]
    #     `key` must be a Symbol or a String.
    #     `array_like` is column data to be assigned.
    #     It must be one of `Vector` or `Arrow::Array` or `Array`.
    #   @return [DataFrame]
    #     assigned DataFrame.
    #   @example Assign a new column
    #     comecome
    #
    #     # =>
    #     #<RedAmber::DataFrame : 3 x 2 Vectors, 0x00000000000280dc>
    #       name         age
    #       <string> <uint8>
    #     0 Yasuko        68
    #     1 Rui           49
    #     2 Hinata        28
    #
    #     brothers = ['Santa', nil, 'Momotaro']
    #     comecome.assign(brother: brothers)
    #     # or
    #     comecome.assign({ brother: brothers })
    #     # or
    #     comecome.assign(:brother, brothers)
    #     # or
    #     comecome.assign([:brother, brothers])
    #
    #     # =>
    #     #<RedAmber::DataFrame : 3 x 3 Vectors, 0x000000000004077c>
    #       name         age brother
    #       <string> <uint8> <string>
    #     0 Yasuko        68 Santa
    #     1 Rui           49 (nil)
    #     2 Hinata        28 Momotaro
    #
    #   @example Assign new data for a existing column
    #     comecome.assign(age: comecome[:age] + 29)
    #
    #     # =>
    #     #<RedAmber::DataFrame : 3 x 2 Vectors, 0x0000000000065860>
    #       name         age
    #       <string> <uint8>
    #     0 Yasuko        97
    #     1 Rui           78
    #     2 Hinata        57
    #
    # @overload assign
    #   accepts block yielding pairs of key and values.
    #
    #   @yield [self]
    #     the block is called within the context of self.
    #     (Block is called by instance_eval(&block). )
    #   @yieldreturn [Array<key, array_like>, Hash(key => array_like)]
    #     `key` must be a Symbol or a String.
    #     `array_like` is column data to be assigned.
    #     It must be one of `Vector` or `Arrow::Array` or `Array`.
    #   @return [DataFrame]
    #      assigned DataFrame.
    #   @example Assign new data for a existing column by block
    #     comecome.assign { { age: age + 29 } }
    #     # or
    #     comecome.assign { [:age, age + 29] }
    #     # or
    #     comecome.assign { [[:age, age + 29]] }
    #
    #     # =>
    #     #<RedAmber::DataFrame : 3 x 2 Vectors, 0x000000000007d640>
    #       name         age
    #       <string> <uint8>
    #     0 Yasuko        97
    #     1 Rui           78
    #     2 Hinata        57
    #
    # @overload assign(keys)
    #   accepts keys from argument and pairs of key and values from block.
    #
    #   @param keys [Symbol, String] keys of columns to create or update.
    #   @yield [self]
    #     the block is called within the context of self.
    #     (Block is called by instance_eval(&block).)
    #   @yieldreturn [Array<array_like>]
    #     column data to be assigned.
    #     `array_like` must be one of `Vector` or `Arrow::Array` or `Array`.
    #   @return [DataFrame]
    #     assigned DataFrame.
    #   @example Assign new data for a existing column by block
    #     comecome.assign(:age) { age + 29 }
    #
    #     # =>
    #     #<RedAmber::DataFrame : 3 x 2 Vectors, 0x000000000007af94>
    #       name         age
    #       <string> <uint8>
    #     0 Yasuko        97
    #     1 Rui           78
    #     2 Hinata        57
    #
    #   @example Assign multiple data
    #     comecome.assign(:age_in_1993, :brother) do
    #       [
    #         age + 29,
    #         ['Santa', nil, 'Momotaro'],
    #       ]
    #     end
    #
    #     # =>
    #     #<RedAmber::DataFrame : 3 x 4 Vectors, 0x00000000000b363c>
    #       name         age age_in_1993 brother
    #       <string> <uint8>     <uint8> <string>
    #     0 Yasuko        68          97 Santa
    #     1 Rui           49          78 (nil)
    #     2 Hinata        28          57 Momotaro
    #
    def assign(...)
      assign_update(false, ...)
    end

    # Assign new or updated variables (columns) and create an updated DataFrame.
    # - Array-like variables with new keys will append new columns from left.
    # - Array-like variables with exisiting keys will update corresponding vectors.
    # - Symbol key and String key are considered as the same key.
    # - If assigner is empty or nil, returns self.
    #
    # @overload assign_left(key_value_pairs)
    #   accepts pairs of key and values by an Array or a Hash.
    #
    #   @param key_value_pairs [Array<key, array_like>, Hash{key => array_like}]
    #     `key` must be a Symbol or a String.
    #     `array_like` is column data to be assigned.
    #     It must be one of `Vector` or `Arrow::Array` or `Array`.
    #   @return [DataFrame]
    #     assigned DataFrame.
    #   @example Assign a new column from left
    #     df
    #
    #     # =>
    #     #<RedAmber::DataFrame : 5 x 3 Vectors, 0x000000000000c10c>
    #         index    float string
    #       <uint8> <double> <string>
    #     0       0      0.0 A
    #     1       1      1.1 B
    #     2       2      2.2 C
    #     3       3      NaN D
    #     4   (nil)    (nil) (nil)
    #
    #     df.assign_left(new_index: df.indices(1))
    #
    #     # =>
    #     #<RedAmber::DataFrame : 5 x 4 Vectors, 0x000000000001787c>
    #       new_index   index    float string
    #         <uint8> <uint8> <double> <string>
    #     0         1       0      0.0 A
    #     1         2       1      1.1 B
    #     2         3       2      2.2 C
    #     3         4       3      NaN D
    #     4         5   (nil)    (nil) (nil)
    #
    # @overload assign_left
    #   accepts block yielding pairs of key and values.
    #
    #   @yield [self]
    #     the block is called within the context of self.
    #     (Block is called by instance_eval(&block). )
    #   @yieldreturn [Array<key, array_like>, Hash(key => array_like)]
    #     `key` must be a Symbol or a String.
    #     `array_like` is column data to be assigned.
    #     It must be one of `Vector` or `Arrow::Array` or `Array`.
    #   @return [DataFrame]
    #     assigned DataFrame.
    #
    # @overload assign_left(keys)
    #   accepts keys from argument and pairs of key and values from block.
    #
    #   @param keys [Symbol, String]
    #     keys of columns to create or update.
    #   @yield [self]
    #     the block is called within the context of self.
    #     (Block is called by instance_eval(&block).)
    #   @yieldreturn [Array<array_like>]
    #     column data to be assigned.
    #     `array_like` must be one of `Vector` or `Arrow::Array` or `Array`.
    #   @return [DataFrame]
    #     assigned DataFrame.
    #
    def assign_left(...)
      assign_update(true, ...)
    end

    private

    def assign_update(append_to_left, *assigner, &block)
      if block
        assigner_from_block = instance_eval(&block)
        assigner =
          case assigner_from_block
          in _ if assigner.empty? # block only
            [assigner_from_block]
          in [Vector, *] | [Array, *] | [Arrow::Array, *]
            assigner.zip(assigner_from_block)
          else
            assigner.zip([assigner_from_block])
          end
      end

      case assigner
      in [] | [nil] | [{}] | [[]]
        return self
      in [(Symbol | String) => key, (Vector | Array | Arrow::Array) => array]
        key_array_pairs = { key => array }
      in [Hash => key_array_pairs]
      # noop
      in [Array => array_in_array]
        key_array_pairs = try_convert_to_hash(array_in_array)
      in [Array, *] => array_in_array1
        key_array_pairs = try_convert_to_hash(array_in_array1)
      else
        raise DataFrameArgumentError, "Invalid argument #{assigner}"
      end

      updater = {}
      appender = {}
      key_array_pairs.each do |key, array|
        raise DataFrameArgumentError, "Empty column data: #{key} => nil" if array.nil?

        if keys.include? key
          updater[key] = array
        else
          appender[key] = array
        end
      end
      fields, arrays = *update_fields_and_arrays(updater)
      return self if appender.is_a?(DataFrame)

      unless appender.empty?
        append_to_fields_and_arrays(appender, fields, arrays, append_to_left)
      end

      DataFrame.create(Arrow::Table.new(Arrow::Schema.new(fields), arrays))
    end

    def try_convert_to_hash(array)
      array.to_h
    rescue TypeError
      [array].to_h
    end

    def rename_by_hash(key_pairs)
      not_existing_keys = key_pairs.keys - keys
      unless not_existing_keys.empty?
        raise DataFrameArgumentError, "Not existing: #{not_existing_keys}"
      end
      return self if key_pairs.all? { |k, v| k == v }

      fields =
        keys.map do |key|
          new_key = key_pairs[key]
          if new_key
            Arrow::Field.new(new_key.to_sym, @table[key].data_type)
          else
            @table.schema[key]
          end
        end
      DataFrame.create(Arrow::Table.new(Arrow::Schema.new(fields), @table.columns))
    end

    def update_fields_and_arrays(updater)
      fields = @table.columns.map(&:field)
      arrays = @table.columns.map(&:data) # chunked_arrays
      keys.each_with_index do |key, i|
        data = updater[key]
        next unless data

        if data.size != size
          raise DataFrameArgumentError, "Data size mismatch (#{data.size} != #{size})"
        end

        if data.respond_to?(:to_arrow_chunked_array)
          chunked_array = data.to_arrow_chunked_array
        else
          if data.respond_to?(:to_arrow_array)
            a = data.to_arrow_array
          else
            a = Arrow::Array.new(data)
          end
          chunked_array = Arrow::ChunkedArray.new([a])
        end
        fields[i] = Arrow::Field.new(key, chunked_array.value_data_type)
        arrays[i] = chunked_array
      end
      [fields, arrays]
    end

    def append_to_fields_and_arrays(appender, fields, arrays, append_to_left)
      enum = append_to_left ? appender.reverse_each : appender.each
      enum.each do |key, data|
        if data.size != size
          raise DataFrameArgumentError, "Data size mismatch (#{data.size} != #{size})"
        end

        a = Arrow::Array.new(data.is_a?(Vector) ? data.to_a : data)

        if append_to_left
          fields.unshift(Arrow::Field.new(key.to_sym, a.value_data_type))
          arrays.unshift(Arrow::ChunkedArray.new([a]))
        else
          fields << Arrow::Field.new(key.to_sym, a.value_data_type)
          arrays << Arrow::ChunkedArray.new([a])
        end
      end
    end
  end
end
