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
    ]

    STRING_TYPES = [
      'char',
    ]

    NATIVE_C_TYPES = NUMBER_TYPES + STRING_TYPES

    class << self

      # This is used to resolve overloaded functions
      def type_group(a, is_pointer = false, prefix = nil)
        # exact same type
        if NATIVE_C_TYPES.include?(a)
          if NUMBER_TYPES.include?(a)
            # number synonym
            is_pointer ? :number_ptr : :number
          else
            # string synonym
            raise "Not implemented yet"
            # :string
          end
        else
          # custom class / type
          prefix ? "#{prefix}.#{a}" : a
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
        arg = function.arguments[index]
        arg = arg ? type_group(arg.type, arg.is_pointer?, function.prefix) : nil
        slot = hash[arg]
        if slot.nil?
          hash[arg] = function
        elsif slot.kind_of?(Hash)
          insert_by_type(slot, function, index + 1)
        else
          raise "Cannot filter functions" if arg.nil?
          h = {}
          insert_by_type(h, slot, index + 1)
          insert_by_type(h, function, index + 1)
          hash[arg] = h
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

    def is_native?
      NATIVE_C_TYPES.include?(type)
    end

    def create_type
      (is_const? ? 'const ' : '') +
      ((is_native? && !is_pointer?) ? "#{type} " : "#{type} *")
    end

    def in_call_type
      (is_native? || is_pointer?) ? name : "*#{name}"
    end

    private
      def parse_xml
        @type = (@xml/'type').innerHTML
        if @type =~ /^(const\s+|)(.*?)\s*(\&amp;)?$/
          @const = $1 != ''
          @type  = $2
          @ref   = $3
        end

        if @type =~ /^\s*<[^>]+>(.*?)<.*>(.*)$/
          @type = $1

          if $2 != ''
            @pointer = $2
          end
        elsif @type =~ /(.*?)\s*(\*+)$/
          @type = $1
          @pointer = $2
        end

        @name = unescape((@xml/'declname').innerHTML)
        @default = (@xml/'defval') ? unescape((@xml/'defval').innerHTML) : nil
        @default = nil if @default == ''
      end
  end
end # Namespace
