require 'dub/entities_unescape'
require 'dub/parser'
require 'dub/namespace'
require 'dub/group'
require 'dub/klass'
require 'dub/function'
require 'dub/argument'
require 'logger'

module Dub
  def self.logger=(logger)
    @@logger = logger
  end

  def self.logger
    @@logger ||= begin
      logger = Logger.new(STDERR)
      logger.level == Logger::INFO
      logger
    end
  end

  def self.parse(filename)
    Dub::Parser.new(filename)
  end
end
