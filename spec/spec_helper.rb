require 'rubygems'
require 'rspec'
require 'pathname'
require 'rake'

spec_helper = Pathname( __FILE__ )
SPECDIR = spec_helper.parent

def load_task(name)
  return false if (@loaded ||= {})[name]
  load File.join(SPECDIR, '..', 'tasks', name)
  @loaded[name] = true
end

$:.unshift(File.expand_path( spec_helper.parent.parent.to_s + '/lib' ))
