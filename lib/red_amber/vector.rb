# frozen_string_literal: true

module RedAmber
  # Columnar data object
  #   @data : holds Arrow::ChunkedArray
  class Vector
    # mix-in
    include VectorFunctions
    include VectorUpdatable

    # chunked_array may come from column.data
    def initialize(array)
      @key = nil # default is 'headless'
      case array
      when Vector
        @data = array.data
      when Arrow::Array, Arrow::ChunkedArray
        @data = array
      when Array
        @data = Arrow::Array.new(array)
      else
        raise VectorArgumentError, 'Unknown array in argument'
      end
    end

    attr_reader :data
    attr_accessor :key

    def to_s
      @data.to_a.inspect
    end

    def inspect(limit: 80)
      sio = StringIO.new << '['
      to_a.each_with_object(sio).with_index do |(e, s), i|
        next_str = "#{s.size > 1 ? ', ' : ''}#{e.inspect}"
        if (s.size + next_str.size) < limit
          s << next_str
        else
          s << ', ... ' if i < size
          break
        end
      end
      sio << ']'

      format "#<#{self.class}(:#{type}, size=#{size}):0x%016x>\n%s\n", object_id, sio.string
    end

    def values
      @data.values
    end
    alias_method :to_a, :values
    alias_method :entries, :values

    def size
      # only defined :length in Arrow?
      @data.length
    end
    alias_method :length, :size
    alias_method :n_rows, :size
    alias_method :nrow, :size

    def type
      @data.value_type.nick.to_sym
    end

    def boolean?
      type == :boolean
    end

    def numeric?
      type_class < Arrow::NumericDataType
    end

    def string?
      type == :string
    end

    def temporal?
      type_class < Arrow::TemporalDataType
    end

    def type_class
      @data.value_data_type.class
    end

    # def each() end

    def chunked?
      @data.is_a? Arrow::ChunkedArray
    end

    def n_chunks
      chunked? ? @data.n_chunks : 0
    end

    # def each_chunk() end

    def tally
      hash = values.tally
      if (type_class < Arrow::FloatingPointDataType) && is_nan.any
        a = 0
        hash.each do |key, value|
          if key.is_a?(Float) && key.nan?
            hash.delete(key)
            a += value
          end
        end
        hash[Float::NAN] = a
      end
      hash
    end

    def value_counts
      values, counts = Arrow::Function.find(:value_counts).execute([data]).value.fields
      values.zip(counts).to_h
    end

    def n_nulls
      @data.n_nulls
    end
    alias_method :n_nils, :n_nulls

    def n_nans
      numeric? ? is_nan.to_a.count(true) : 0
    end
  end
end
