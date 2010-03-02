require 'dub/entities_unescape'

module Dub
  class Argument
    include Dub::EntitiesUnescape
    attr_reader :type, :name, :default, :function, :xml

    NUMBER_TYPES = [
      'float',
      'double',
      'size_t',
      'unsigned int',
      'uint',
      'int',
      'size_t',
      'unsigned int',
      'uint',
      'bool',
      'uchar'
    ]

    STRING_TYPES = [
      'char',
    ]

    NATIVE_C_TYPES = NUMBER_TYPES + STRING_TYPES

    class << self

      # This is used to resolve overloaded functions
      def type_group(arg)
        # exact same type
        if NATIVE_C_TYPES.include?(arg.type)
          if NUMBER_TYPES.include?(arg.type)
            # number synonym
            arg.is_pointer? ? :number_ptr : :number
          else
            # string synonym
            raise "Not implemented yet"
            # :string
          end
        else
          # custom class / type
          arg.id_name
        end
      end

      # group is a list of functions, index = argument index
      def decision_tree(group)
        hash = {}
        group.each do |function|
          insert_by_type(hash, function)
        end
        hash
      end

      # Insert a function into the hash, using the argument at the given
      # index to filter
      def insert_by_type(hash, function, index = 0)
        arg  = function.arguments[index]
        type = arg ? type_group(arg) : nil
        slot = hash[type]
        if slot.nil?
          hash[type] = function
        elsif slot.kind_of?(Hash)
          insert_by_type(slot, function, index + 1)
        elsif type.nil?
          # ignore

          # TODO: log level
          # puts "Cannot filter functions #{function.source}"
        else
          h = {}
          insert_by_type(h, slot, index + 1)
          insert_by_type(h, function, index + 1)
          hash[type] = h
        end
      end
    end

    def initialize(function, xml)
      @function, @xml = function, xml
      parse_xml
    end

    def signature
      "#{is_const? ? 'const ' : ''}#{type}#{is_ref? ? '&' : ''}"
    end

    def full_type
      container = function.parent
      if container.kind_of?(Klass)
        container = container.parent
      end
      container ? "#{container.name}::#{type}" : type
    end

    def id_name
      full_type.gsub('::', '.')
    end

    alias inspect signature

    def is_ref?
      @ref
    end

    def is_pointer?
      !@pointer.nil?
    end

    def is_const?
      @const
    end

    def has_default?
      !@default.nil?
    end

    def is_return_value?
      @is_return_value
    end

    def is_native?
      NATIVE_C_TYPES.include?(type)
    end

    def create_type
      (is_const? ? 'const ' : '') +
      if (is_return_value? && is_ref?) || (is_native? && !is_pointer?)
        "#{type} "
      else
        "#{type} *"
      end
    end

    def in_call_type
      (is_native? || is_pointer?) ? name : "*#{name}"
    end

    private
      def parse_xml
        if type = (@xml/'type').first
          # param
          set_type(type)

          @name = unescape((@xml/'declname').innerHTML)
          @default = (@xml/'defval') ? unescape((@xml/'defval').innerHTML) : nil
          @default = nil if @default == ''
          expand_default_type if @default
        else
          # return value
          @is_return_value = true
          set_type(@xml/'')
        end
      end

      def set_type(type)
        type = type.innerHTML
        if type =~ /^(const\s+|)(.*?)\s*(\&amp;)?$/
          @const = $1 != ''
          type  = $2
          @ref   = $3
        end

        if type =~ /<[^>]+>(.*?)<.*>(.*)$/
          type = $1

          if $2 != ''
            @pointer = $2
          end
        elsif type =~ /(.*?)\s*(\*+)$/
          type = $1
          @pointer = $2
        end
        @type = type
      end

      # Replace something like AUTO_STEP by cv::Mat::AUTO_STEP
      def expand_default_type
        container = @function.parent
        if container && container.enums.include?(@default)
          @default = "#{container.full_type}::#{@default}"
        elsif container = container.parent && container.enums.include?(@default)
          @default = "#{container.full_type}::#{@default}"
        end
      end
  end
end # Namespace
