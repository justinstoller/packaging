require 'yaml'
require 'erb'
require 'benchmark'
load File.expand_path('../build.rake', __FILE__)

##
# Where we get the data for our project depends on if a PARAMS_FILE environment
# variable is passed with the rake call. PARAMS_FILE should be a path to a yaml
# file containing all of the build parameters for a project, which are read
# into our BuildInstance object. If no build parameters file is specified, we
# assume input via the original methods of build_data.yaml and
# project_data.yaml. This also applies to the pl:fetch and pl:load_extras
# tasks, which are supplementary means of gathering data. These two are not
# used if a PARAMS_FILE is passed.

##
# Create our BuildInstance object, which will contain all the data about our
# proposed build
#
@build = Packaging::BuildInstance.new

if ENV['PARAMS_FILE'] && ENV['PARAMS_FILE'] != ''
  @build.set_params_from_file(ENV['PARAMS_FILE'])
else
  # Load information about the project from the default params files
  #
  @build.set_params_from_file('ext/project_data.yaml') if File.readable?('ext/project_data.yaml')
  @build.set_params_from_file('ext/build_defaults.yaml') if File.readable?('ext/build_defaults.yaml')
end

@build.override_params_with_environment
##
# For backwards compatibilty, we set build:@name to build:@project. @name was
# renamed to @project in an effort to align the variable names with what has
# been supported for parameter names in the params files.
@build.name = @build.project
# We also set @tar_host to @yum_host if @tar_host is not set. This is in
# another effort to fix dumb mistakes. Early on, we just assumed tarballs would
# go to @yum_host (why? probably just laziness) but this is not ideal and does
# not make any sense when looking at the code. Now there's a @tar_host
# variable, but for backwards compatibility, we'll default back to @yum_host if
# @tar_host isn't set.
@build.tar_host ||= @build.yum_host

if @build.debug
  @build.print_params
end

##
# MM 1-22-2013
# We have long made all of the variables available to erb templates in the
# various projects. The problem is now that we've switched to encapsulating all
# of this inside a build object, that information is no longer available. This
# section is for backwards compatibility only. It sets an instance variable
# for all of the parameters inside the build object. This is repeated in
# 20_setupextrasvars.rake. Note: The intention is to eventually abolish this
# behavior. We want to access information from the build object, not in what
# are essentially globally available rake variables.
#
@build.params.each do |param, value|
  self.instance_variable_set("@#{param}", value)
end

##
# Issue a deprecation warning if the packaging repo wasn't loaded by the loader
unless @using_loader
  warn "
  DEPRECATED: The packaging repo tasks are now loaded by 'packaging.rake'.
  Please update your Rakefile or loading task to load
  'ext/packaging/packaging.rake' instead of 'ext/packaging/tasks/*' (25-Jun-2013).
  "
end

