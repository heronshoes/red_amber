# frozen_string_literal: true

module RedAmber
  # Values in variable (columnar) data object
  #   @data : holds Arrow::ChunkedArray
  class Vector
    # mix-in
    include Helper
    include ArrowFunction
    include VectorUpdatable
    include VectorSelectable

    using RefineArrayLike

    # Quicker constructor of Vector.
    #
    # @param arrow_array [Arrow::Array]
    #   Arrow::Array object to have in the Vector.
    # @return [Vector]
    #   created Vector.
    # @note This method doesn't check argment type.
    #
    def self.create(arrow_array)
      instance = allocate
      instance.instance_variable_set(:@data, arrow_array)
      instance
    end

    # Return true if it is an aggregation function.
    #
    # @param function [Symbol]
    #   function name to test.
    # @return [Booleans]
    #   true if function is a aggregation function, otherwise false.
    #
    # @example
    #   Vector.aggregate?(:mean) # => true
    #
    #   Vector.aggregate?(:round) # => false
    #
    # @since 0.3.1
    #
    def self.aggregate?(function)
      %i[
        all all? any any? approximate_median count count_distinct count_uniq
        max mean median min min_max product quantile sd std stddev sum
        unbiased_variance var variance
      ].include?(function.to_sym)
    end

    # Create a Vector.
    #
    # @param array [Array, Vector, Range, Arrow::Array, #to_arrow_array]
    #   array-like.
    # @return [Vector]
    #   created Vector.
    #
    # @note default is headless Vector and '@key == nil'
    def initialize(*array)
      @data =
        case array
        in [Vector => v]
          v.data
        in [Range => r]
          Arrow::Array.new(Array(r))
        in [Arrow::Array | Arrow::ChunkedArray]
          array[0]
        in [arrow_array_like] if arrow_array_like.respond_to?(:to_arrow_array)
          arrow_array_like.to_arrow_array
        else
          Arrow::Array.new(array.flatten)
        end
    end

    # Entity of Vector.
    #
    # @return [Arrow::Array]
    #
    attr_reader :data
    alias_method :to_arrow_array, :data

    # Associated key name when self is in a DataFrame.
    #
    # Default Vector is 'head-less' (key-less).
    # @return [Symbol]
    #
    attr_accessor :key

    # Return other as a Vector which is same data type as self.
    #
    # @param other [Vector, Array, Arrow::Array, Arrow::ChunkedArray]
    #   a source array-like which will be converted.
    # @return [Vector]
    #   resolved Vector.
    # @example Integer to String
    #   Vector.new('A').resolve([1, 2])
    #
    #   # =>
    #   #<RedAmber::Vector(:string, size=2):0x00000000000037b4>
    #   ["1", "2"]
    #
    # @example String to Ineger
    #   Vector.new(1).resolve(["A"])
    #
    #   # =>
    #   #<RedAmber::Vector(:uint8, size=1):0x00000000000037dc>
    #   [65]
    #
    # @example Upcast to uint16
    #   vector = Vector.new(256)
    #
    #   # =>
    #   #<RedAmber::Vector(:uint16, size=1):0x000000000000c1fc>
    #   [256]
    #
    #   vector.resolve([1, 2])
    #
    #   # =>
    #   # Not a uint8 Vector
    #   #<RedAmber::Vector(:uint16, size=2):0x000000000000c328>
    #   [1, 2]
    #
    # @since 0.3.1
    #
    def resolve(other)
      case other
      when Vector
        Vector.create(data.resolve(other.data))
      when Array, Arrow::Array, Arrow::ChunkedArray
        Vector.create(data.resolve(other))
      else
        raise VectorArgumentError, "invalid argument: #{other}"
      end
    end

    # String representation of self like an Array.
    #
    # @return [String]
    #   return self as same as Array's inspect.
    #
    def to_s
      @data.to_a.inspect
    end

    # String representation of self.
    #
    # According to `ENV [“RED_AMBER_OUTPUT_MODE”].upcase`,
    # - If it is 'MINIMUM', returns class and size.
    # - If it is otherwise, returns class, size and preview.
    #   Default value of the ENV is 'Table'.
    # @param limit [Integer]
    #   max width of the result.
    # @return [String]
    #   show information of self as a String.
    # @example Default (ENV ['RED_AMBER_OUTPUT_MODE'] == 'Table')
    #   puts vector.inspect
    #
    #   # =>
    #   #<RedAmber::Vector(:uint8, size=3):0x00000000000037f0>
    #   [1, 2, 3]
    #
    # @example In case of ENV ['RED_AMBER_OUTPUT_MODE'] == 'Minimum'
    #   puts vector.inspect
    #
    #   # =>
    #   RedAmber::Vector(:uint8, size=3)
    #
    def inspect(limit: 80)
      if ENV.fetch('RED_AMBER_OUTPUT_MODE', 'Table').casecmp('MINIMUM').zero?
        # Better performance than `.upcase == 'MINIMUM'`
        "#{self.class}(:#{type}, size=#{size})"
      else
        sio = StringIO.new << '['
        each.with_index do |e, i|
          next_str = "#{sio.size > 1 ? ', ' : ''}#{e.inspect}"
          if (sio.size + next_str.size) < limit
            sio << next_str
          else
            sio << ', ... ' if i < size
            break
          end
        end
        sio << ']'

        format "#<#{self.class}(:#{type}, size=#{size}):0x%016x>\n%s\n",
               object_id, sio.string
      end
    end

    # Convert to an Array.
    #
    # @return [Array]
    #   array representation.
    #
    def to_ary
      @data.values
    end
    alias_method :to_a, :to_ary
    alias_method :values, :to_ary
    alias_method :entries, :to_ary

    # Indeces from 0 to size-1 by Array.
    #
    # @return [Array]
    #   indices.
    #
    def indices
      (0...size).to_a
    end
    alias_method :indexes, :indices
    alias_method :indeces, :indices

    # Vector size.
    #
    # @return [Integer]
    #   size of self.
    #
    def size
      # only defined :length in Arrow?
      @data.length
    end
    alias_method :length, :size
    alias_method :n_rows, :size
    alias_method :nrow, :size

    # Test wheather self is empty.
    #
    # @return [true, false]
    #   true if self is empty.
    #
    def empty?
      size.zero?
    end

    # Type nickname of self.
    #
    # @return [Symbol]
    #   type nickname of values.
    #
    def type
      list? ? :list : @data.value_type.nick.to_sym
    end

    # Type Class of self.
    #
    # @return [type_Class]
    #   type class.
    #
    def type_class
      @data.type_class
    end

    # Test if self is a boolean Vector.
    #
    # @return [true, false]
    #   test result.
    #
    def boolean?
      @data.boolean?
    end

    # Test if self is a numeric Vector.
    #
    # @return [true, false]
    #   test result.
    #
    def numeric?
      @data.numeric?
    end

    # Test if self is a float Vector.
    #
    # @return [true, false]
    #   test result.
    #
    def float?
      @data.float?
    end

    # Test if self is a integer Vector.
    #
    # @return [true, false]
    #   test result.
    #
    def integer?
      @data.integer?
    end

    # Test if self is a string Vector.
    #
    # @return [true, false]
    #   test result.
    #
    def string?
      @data.string?
    end

    # Test if self is a dictionary Vector.
    #
    # @return [true, false]
    #   test result.
    #
    def dictionary?
      @data.dictionary?
    end

    # Test if self is a temporal Vector.
    #
    # @return [true, false]
    #   test result.
    #
    def temporal?
      @data.temporal?
    end

    # Test if self is a list Vector.
    #
    # @return [true, false]
    #   test result.
    #
    def list?
      @data.list?
    end

    # Iterates over Vector elements or returns a Enumerator.
    #
    # @overload each
    #   Returns a new Enumerator if no block given.
    #
    #   @return [Enumerator]
    #     Enumerator of each elements.
    #
    # @overload each
    #   When a block given, passes each element in self to the block.
    #
    #   @yield [Object]
    #     each element.
    #   @yieldparam element [Object]
    #     passes element by a block parameter.
    #   @yieldreturn [Object]
    #     evaluated result value from the block.
    #   @return [self]
    #     returns self.
    #
    def each
      return enum_for(:each) unless block_given?

      size.times do |i|
        yield data[i]
      end
      self
    end

    # Returns a Vector from collected objects from the block.
    #
    # @overload map
    #   Returns a new Enumerator if no block given.
    #
    #   @return [Enumerator]
    #     a new Enumerator.
    #
    # @overload map
    #   When a block given, calls the block with successive elements.
    #   Returns a Vector of the objects returned by the block.
    #
    #   @yield [Object]
    #     each element.
    #   @yieldparam element [Object]
    #     passes element by a block parameter.
    #   @yieldreturn [Object]
    #     evaluated result value from the block.
    #   @return [self]
    #     returns the collected values from the block as a Vector.
    #
    def map(&block)
      return enum_for(:map) unless block

      Vector.new(to_a.map(&block))
    end
    alias_method :collect, :map

    # @api private
    #
    def chunked?
      @data.is_a? Arrow::ChunkedArray
    end

    # @api private
    #
    def n_chunks
      chunked? ? @data.n_chunks : 0
    end

    # def each_chunk() end

    # Returns a hash containing the counts of equal elements.
    #
    # - Each key is an element of self.
    # - Each value is the number of elements equal to the key.
    # @return [Hash]
    #   result in a Hash.
    #
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

    # @api private
    # Arrow imprementation of #tally
    def value_counts
      values, counts = Arrow::Function.find(:value_counts).execute([data]).value.fields
      values.zip(counts).to_h
    end

    # Count nils in self.
    #
    # @return [Integer]
    #   the number of nils.
    #
    def n_nulls
      @data.n_nulls
    end
    alias_method :n_nils, :n_nulls

    # Count NaNs in self if self is a numeric Vector
    #
    # @return [Integer]
    #   the number of Float::NANs. If self is not a numeric Vector,
    #   returns 0.
    #
    def n_nans
      numeric? ? is_nan.to_a.count(true) : 0
    end

    # Return true if self has any nil.
    #
    # @return [true, false]
    #   true or false.
    #
    def has_nil?
      is_nil.any
    end

    def coerce(other)
      [Vector.new(Array(other) * size), self]
    end

    # Spread the return value of an aggregate function as if
    #   it is a element-wise function.
    #
    # @overload propagate(function)
    #   Returns a Vector of same size as self spreading the value from function.
    #
    #   @param function [Symbol] a name of aggregation function for self.
    #     Return value of the function must be a scalar.
    #   @return [Vector] Returns a Vector that is the same size as self
    #     and such that all elements are the same as the result of aggregation `function`.
    #   @example propagate by an aggragation function name
    #     vec = Vector.new(1, 2, 3, 4)
    #     vec.propagate(:mean)
    #     # =>
    #     #<RedAmber::Vector(:double, size=4):0x000000000001985c>
    #     [2.5, 2.5, 2.5, 2.5]
    #
    # @overload propagate
    #   Returns a Vector of same size as self spreading the value from block.
    #
    #   @yield [self]
    #     gives self to the block.
    #   @yieldparam self [Vector]
    #     self.
    #   @yieldreturn [scalar]
    #     a scalar value.
    #   @return [Vector]
    #     returns a Vector that is the same size as self
    #     and such that all elements are the same as the yielded value from the block.
    #   @example propagate by a block
    #     vec.propagate { |v| v.mean.round }
    #     # =>
    #     #<RedAmber::Vector(:uint8, size=4):0x000000000000cb98>
    #     [3, 3, 3, 3]
    #
    # @since 0.3.1
    #
    def propagate(function = nil, &block)
      value =
        if block
          raise VectorArgumentError, "can't specify both function and block" if function

          yield self
        else
          function = function&.to_sym
          unless function && respond_to?(function) && Vector.aggregate?(function)
            raise VectorArgumentError, "illegal function: #{function.inspect}"
          end

          send(function)
        end
      Vector.new([value] * size)
    end
    alias_method :expand, :propagate

    private # =======

    def exec_func_unary(function, options)
      options = nil if options.empty?
      find(function).execute([data], options)
    end

    def exec_func_binary(function, other, options)
      options = nil if options.empty?
      case other
      when Vector
        find(function).execute([data, other.data], options)
      when Arrow::Array, Arrow::ChunkedArray, Arrow::Scalar,
           Array, Numeric, String, TrueClass, FalseClass
        find(function).execute([data, other], options)
      end
    end

    def get_scalar(datum)
      output = datum.value
      case output
      when Arrow::StringScalar then output.to_s
      when Arrow::StructScalar
        output.value.map { |s| s.is_a?(Arrow::StringScalar) ? s.to_s : s.value }
      else
        output.value
      end
    end
  end
end
