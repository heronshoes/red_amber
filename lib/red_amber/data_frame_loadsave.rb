# frozen_string_literal: true

module RedAmber
  # mix-ins for the class DataFrame
  module DataFrameLoadSave
    # Enable `self.load` as class method of DataFrame
    def self.included(klass)
      klass.extend ClassMethods
    end

    # Enable `self.load` as class method of DataFrame
    module ClassMethods
      # Load DataFrame via Arrow::Table.load
      def load(path, options = {})
        DataFrame.new(Arrow::Table.load(path, options))
      end
    end

    # Save DataFrame
    def save(output, options = {})
      @table.save(output, options)
    end

    # Save and reload to cast automatically
    #   Via tsv format file temporally as default
    #
    #   experimental feature
    def auto_cast(format: :tsv)
      return self if empty?

      tempfile = Arrow::ResizableBuffer.new(1024)
      save(tempfile, format: format)
      DataFrame.load(tempfile, format: format)
    end
  end
end
