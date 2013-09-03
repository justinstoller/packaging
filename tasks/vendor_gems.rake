# This is an optional pre-tar-task, so we only want to present it if we're
# using it
if @build.pre_tar_task == "package:vendor_gems"
  namespace :package do
    desc "vendor gems required by project"
    task :vendor_gems do
      check_tool("bundle")
      require 'bundler'

      # Cache all the gems locally without using the shared GEM_PATH
      Bundler.settings[:cache_all] = true
      Bundler.settings[:local] = true
      Bundler.settings[:disable_shared_gems] = true
      # Make sure we cache all the gems, despite what the local config file says...
      Bundler.settings.without = []

      # Stupid bundler requires this because it's not abstracted out into a library that doesn't need IO
      Bundler.ui = Packaging::UI.new()
      Bundler.rubygems.ui = Packaging::RubyGemsProxy.new(Bundler.ui)
      Bundler.ui.level = "debug"

      # Load the the Gemfile and resolve gems using RubyGems.org
      definition = Bundler.definition
      definition.validate_ruby!
      definition.resolve_remotely!

      mkdir_p Bundler.app_cache

      # Cache the gems
      definition.specs.each do |spec|
        # Fetch Rubygem specs
        Bundler::Fetcher.fetch(spec) if spec.source.is_a?(Bundler::Source::Rubygems)
        # Cache everything but bundler itself...
        spec.source.cache(spec) unless spec.name == "bundler"
      end

    end
  end
end
