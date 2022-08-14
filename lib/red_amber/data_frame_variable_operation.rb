# frozen_string_literal: true

module RedAmber
  # mix-ins for the class DataFrame
  module DataFrameVariableOperation
    # pick up some variables to create sub DataFrame
    def pick(*args, &block)
      picker = args
      if block
        raise DataFrameArgumentError, 'Must not specify both arguments and block.' unless args.empty?

        picker = instance_eval(&block)
      end
      picker = [picker].flatten
      return DataFrame.new if picker.empty? || picker == [nil]

      picker = keys_by_booleans(picker) if booleans?(picker)

      # DataFrame#[] creates a Vector with single key is specified.
      # DataFrame#pick creates a DataFrame with single key.
      return DataFrame.new(@table[picker]) if sym_or_str?(picker)

      raise DataFrameArgumentError, "Invalid argument #{args}"
    end

    # drop some variables to create remainer sub DataFrame
    def drop(*args, &block)
      dropper = args
      if block
        raise DataFrameArgumentError, 'Must not specify both arguments and block.' unless args.empty?

        dropper = instance_eval(&block)
      end
      dropper = [dropper].flatten
      dropper = keys_by_booleans(dropper) if booleans?(dropper)

      picker = keys - dropper
      return DataFrame.new if picker.empty?

      # DataFrame#[] creates a Vector with single key is specified.
      # DataFrame#drop creates a DataFrame with single key.
      return DataFrame.new(@table[picker]) if sym_or_str?(picker)

      raise DataFrameArgumentError, "Invalid argument #{args}"
    end

    # rename variables to create a new DataFrame
    def rename(*renamer, &block)
      if block
        raise DataFrameArgumentError, 'Must not specify both arguments and a block' unless renamer.empty?

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

    # assign variables to create a new DataFrame
    def assign(*assigner, &block)
      appender, fields, arrays = assign_update(*assigner, &block)
      return self if appender.is_a?(DataFrame)

      append_to_fields_and_arrays(appender, fields, arrays, append_to_left: false) unless appender.empty?

      DataFrame.new(Arrow::Table.new(Arrow::Schema.new(fields), arrays))
    end

    def assign_left(*assigner, &block)
      appender, fields, arrays = assign_update(*assigner, &block)
      return self if appender.is_a?(DataFrame)

      append_to_fields_and_arrays(appender, fields, arrays, append_to_left: true) unless appender.empty?

      DataFrame.new(Arrow::Table.new(Arrow::Schema.new(fields), arrays))
    end

    private

    def assign_update(*assigner, &block)
      if block
        raise DataFrameArgumentError, 'Must not specify both arguments and a block' unless assigner.empty?

        assigner = [instance_eval(&block)]
      end
      case assigner
      in [] | [nil] | [{}] | [[]]
        return self
      in [Hash => key_array_pairs]
      # noop
      in [(Symbol | String) => key, (Vector | Array | Arrow::Array) => array]
        key_array_pairs = { key => array }
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
        if keys.include? key
          updater[key] = array
        else
          appender[key] = array
        end
      end
      [appender, *update_fields_and_arrays(updater)]
    end

    def try_convert_to_hash(array)
      array.to_h
    rescue TypeError
      [array].to_h
    rescue TypeError # rubocop:disable Lint/DuplicateRescueException
      raise DataFrameArgumentError, "Invalid argument in Array #{array}"
    end

    def rename_by_hash(key_pairs)
      not_existing_keys = key_pairs.keys - keys
      raise DataFrameArgumentError, "Not existing: #{not_existing_keys}" unless not_existing_keys.empty?

      fields =
        keys.map do |key|
          new_key = key_pairs[key]
          if new_key
            Arrow::Field.new(new_key.to_sym, @table[key].data_type)
          else
            @table.schema[key]
          end
        end
      DataFrame.new(Arrow::Table.new(Arrow::Schema.new(fields), @table.columns))
    end

    def update_fields_and_arrays(updater)
      fields = @table.columns.map(&:field)
      arrays = @table.columns.map(&:data) # chunked_arrays
      keys.each_with_index do |key, i|
        data = updater[key]
        next unless data

        raise DataFrameArgumentError, "Data size mismatch (#{data.size} != #{size})" if data.size != size

        a = Arrow::Array.new(data.is_a?(Vector) ? data.to_a : data)
        fields[i] = Arrow::Field.new(key, a.value_data_type)
        arrays[i] = Arrow::ChunkedArray.new([a])
      end
      [fields, arrays]
    end

    def append_to_fields_and_arrays(appender, fields, arrays, append_to_left: false)
      enum = append_to_left ? appender.reverse_each : appender.each
      enum.each do |key, data|
        raise DataFrameArgumentError, "Data size mismatch (#{data.size} != #{size})" if data.size != size

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

    def keys_by_booleans(booleans)
      keys.select.with_index { |_, i| booleans[i] }
    end
  end
end
