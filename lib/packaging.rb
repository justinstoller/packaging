unless Kernel.respond_to? :require_relative
  def require_relative( lib )
    require File.expand_path( File.dirname(__FILE__) + lib )
  end
end

module Packaging
  require_relative 'packaging/utils'
end

