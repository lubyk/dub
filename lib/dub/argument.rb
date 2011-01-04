require 'dub/entities_unescape'

module Dub
  class Argument
    include Dub::EntitiesUnescape
    attr_reader :name, :default, :function, :xml
    attr_accessor :type, :is_list, :is_list_count
    TYPE_REGEXP = %r{^\s*(\w+\s+|)(const\s+|)([\w\:]+|\.\.\.)(\s*<(.+)>|)(\s*\*+|\s*&|)$}
    NUMBER_TYPES = [
      'float',
      'double',
      'size_t',
      'unsigned int',
      'uint',
      'int',
      'size_t',
      'time_t',
      'unsigned int',
      'uint',
      'bool',
      'uchar',
      'void',
      'int64',
    ]

    STRING_TYPES = [
      'char',
    ]

    BOOL_TYPES = [
      'bool',
    ]

    NATIVE_C_TYPES = NUMBER_TYPES + STRING_TYPES + BOOL_TYPES

    class << self

      # This is used to resolve overloaded functions
      def type_group(arg)
        # exact same type
        if NATIVE_C_TYPES.include?(arg.type)
          if BOOL_TYPES.include?(arg.type)
            :boolean
          elsif STRING_TYPES.include?(arg.type) && arg.is_pointer?
            :string
          else
            # number synonym
            arg.is_pointer? ? :number_ptr : :number
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

    def initialize(function, xml, arg_pos = nil)
      @function, @xml, @argument_position = function, xml, arg_pos
      parse_xml
    end

    def signature
      "#{is_const? ? 'const ' : ''}#{type}#{is_ref? ? '&' : ''}"
    end

    def full_type
      if type =~ /::/
        type
      else
        container = function.parent
        if container.kind_of?(Klass)
          container = container.parent
        end
        container ? "#{container.name}::#{type}" : type
      end
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

    def type
      resolve_type if @template_params
      @type
    end

    def vararg?
      @type == '...'
    end

    def complex?
      resolve_type if @template_params
      @is_complex
    end

    def is_list?
      @is_list
    end

    def is_list_count?
      @is_list_count
    end

    def create_type
      resolve_type if @template_params
      (is_const? ? 'const ' : '') +
      if (is_return_value? && !is_pointer?) || (is_native? && !is_pointer?)
        "#{type} "
      else
        "#{type} *"
      end
    end

    # this is for the cases where we have signatures like
    # HuMoments(double moments[7])
    def array_suffix
      @array_suffix
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
          if @name == ''
            @name = "arg#{@argument_position}"
          elsif @name == @function.name
            @name = "arg_#{@name}"
          end

          if ref = (@xml/'defval/ref').first
            ref.swap(ref.innerHTML)
          end
          @default = (@xml/'defval') ? unescape((@xml/'defval').innerHTML) : nil
          @default = nil if @default == ''
          expand_default_type if @default
        else
          # return value
          @is_return_value = true
          set_type(@xml/'')
        end

        if array = (@xml/'array').first
          @array_suffix = array.innerHTML
        end
      end

      def set_type(type)
        # <type>const <ref refid="classcv_1_1_point__" kindref="compound">Point_</ref>&lt; int &gt; &amp;</type>
        if ref = (type/'ref').first
          @refid = ref[:refid]
          ref.swap(ref.innerHTML)
        end

        type = type.innerHTML
        type = unescape(type).strip

        if type =~ TYPE_REGEXP
          res = $~.to_a

          if res[1].strip == 'const'
            res[2] = res[1]
            res[1] = ""
          end

          @const = res[2].strip == 'const'
          @type = res[3]

          if res[6] == ''
            @pointer = nil
            @res = nil
          elsif res[6] =~ /^\s*(\*+)\s*$/
            @pointer = $1
          else
            @ref = res[6].strip
          end

          @template_params = res[5] ? res[5].split(',').map(&:strip) : nil
        else
          # ERROR
        end
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

      def resolve_type
        params = @template_params
        @template_params = nil
        if container = @function.parent
          if container.kind_of?(Klass)
            container = container.parent
          end
          if container && tclass = container.template_class(@type)
            if instanciation = tclass.instanciations[params]
              @type = instanciation.name
              return
            end
          end
        end

        @type = "#{@type}< #{params.join(', ')} >"
        Dub.logger.warn "Could not resolve templated type #{@type}"
        @is_complex = true
      end
  end
end # Namespace
