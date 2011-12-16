module Dub
  class FunctionGroup < Array
    def initialize(parent, gen = nil)
      @parent, @gen = parent, gen
    end

    def bind(generator)
      self.gen = generator.function_generator
    end

    def generator
      @gen || (@parent && @parent.function_generator)
    end

    def gen=(generator)
      @gen = generator
      @gen_members = nil
    end

    alias gen generator

    def members
      if self.generator
        if @parent.generator
          @gen_members ||= @parent.generator.members_list(self)
        else
          @gen_members ||= generator.namespace_generator.members_list(self)
        end
      else
        self
      end
    end

    def to_s
      generator.group(self)
    end

    def method_name(overloaded_index = nil)
      first.method_name(overloaded_index)
    end

    def map(&block)
      list = self.class.new(@parent, @gen)
      super(&block).each do |e|
        list << e
      end
      list
    end

    def compact
      list = self.class.new(@parent, @gen)
      super.each do |e|
        list << e
      end
      list
    end

    def overloaded_index
      nil
    end

    def <=>(other)
      name <=> other.name
    end

    private
      def method_missing(method, *args)
        first.send(method, *args)
      end

  end
end