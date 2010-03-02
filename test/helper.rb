require 'rubygems'
require 'test/unit'
require 'shoulda'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'dub'

class Test::Unit::TestCase

  def self.fixture(path)
    File.join(File.dirname(__FILE__), 'fixtures', path)
  end

  @@namespacecv_xml = nil

  def fixture(path)
    self.class.fixture(path)
  end

  def namespacecv_xml
    @@namespacecv_xml ||= Dub.parse(fixture('namespacecv.xml'))
  end

  def namespacedub_xml
    @@namespacedub_xml ||= Dub.parse(fixture('app/xml/namespacedub.xml'))
  end
end
