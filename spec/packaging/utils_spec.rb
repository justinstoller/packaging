# -*- ruby -*-
require 'spec_helper'
require 'packaging/utils'
require 'packaging/build_instance'

class ClassIncludingUtils
  include Packaging::Utils

  attr_accessor :build
  def initialize( build = Packaging::BuildInstance.new )
    @build = build
  end
end


describe ClassIncludingUtils do

end
