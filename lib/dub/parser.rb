require 'rubygems'
require 'hpricot'
require 'dub/namespace'

module Dub
  class Parser
    def initialize(filepath)
      @current_dir = File.dirname(filepath)
      @xml = Hpricot::XML(File.read(filepath))
    end

    def [](name)
      namespaces[name.to_s] || groups[name.to_s]
    end

    def namespace(name)
      namespaces[name.to_s]
    end

    def group(name)
      groups[name.to_s]
    end

    def namespaces
      @namespaces ||= begin
        ns = {}
        (@xml/'compounddef[@kind=namespace]').each do |namespace|
          name = (namespace/"compoundname").innerHTML
          ns[name] = Dub::Namespace.new(name, namespace, @current_dir)
        end
        ns
      end
    end

    def groups
      @groups ||= begin
        groups = {}
        (@xml/'compounddef[@kind=group]').each do |namespace|
          name = (namespace/"compoundname").innerHTML
          groups[name] = Dub::Group.new(name, namespace, @current_dir)
        end
        groups
      end
    end
  end # Parser
end
