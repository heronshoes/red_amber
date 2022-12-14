# frozen_string_literal: true

require 'arrow'

require_relative 'red_amber/refinements'
require_relative 'red_amber/helper'

require_relative 'red_amber/data_frame_combinable'
require_relative 'red_amber/data_frame_displayable'
require_relative 'red_amber/data_frame_indexable'
require_relative 'red_amber/data_frame_loadsave'
require_relative 'red_amber/data_frame_reshaping'
require_relative 'red_amber/data_frame_selectable'
require_relative 'red_amber/data_frame_variable_operation'
require_relative 'red_amber/data_frame'
require_relative 'red_amber/group'
require_relative 'red_amber/vector_functions'
require_relative 'red_amber/vector_updatable'
require_relative 'red_amber/vector_selectable'
require_relative 'red_amber/vector'
require_relative 'red_amber/version'

module RedAmber
  class Error < StandardError; end

  class DataFrameArgumentError < ArgumentError; end
  class DataFrameTypeError < TypeError; end

  class VectorArgumentError < ArgumentError; end
  class VectorTypeError < TypeError; end

  class GroupArgumentError < ArgumentError; end
end
