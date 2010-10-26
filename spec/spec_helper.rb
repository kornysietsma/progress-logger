$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'progress-logger'
require 'spec'
require 'spec/autorun'
require 'delorean'

Spec::Runner.configure do |config|
  
end
