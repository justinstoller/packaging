# Title:        Rake task to build Apple packages for #{@project}.
# Author:       Gary Larizza
# Date:         05/18/2012
# Description:  This task will create a DMG-encapsulated package that will
#               install a package on OS X systems. This happens by building
#               a directory tree of files that will then be fed to the
#               packagemaker binary (can be installed by installing the
#               XCode Tools) which will create the .pkg file.
#

# Path to Binaries (Constants)
CP            = '/bin/cp'
INSTALL       = '/usr/bin/install'
DITTO         = '/usr/bin/ditto'
PKGBUILD      = '/usr/bin/pkgbuild'

# Setup task to populate all the variables
task :setup do
  # Read the Apple file-mappings
  begin
    @source_files        = data_from_yaml('ext/osx/file_mapping.yaml')
  rescue
    fail "Could not load Apple file mappings from 'ext/osx/file_mapping.yaml'"
  end
  @package_name          = @build.project
  @title                 = "#{@build.project}-#{@build.version}"
  @reverse_domain        = "com.#{@build.packager}.#{@package_name}"
  @package_major_version = @build.version.split('.')[0]
  @package_minor_version = @build.version.split('.')[1] +
                           @build.version.split('.')[2].split('-')[0].split('rc')[0]
  @pm_restart            = 'None'
  @build_date            = Time.new.strftime("%Y-%m-%dT%H:%M:%SZ")
  @apple_bindir          = '/usr/bin'
  @apple_sbindir         = '/usr/sbin'
  @apple_libdir          = '/usr/lib/ruby/site_ruby'
  @apple_old_libdir      = '/usr/lib/ruby/site_ruby/1.8'
  @apple_docdir          = '/usr/share/doc'
end
if @build.build_dmg
  namespace :package do
    desc "Task for building an Apple Package"
    task :apple => [:setup] do
      bench = Benchmark.realtime do
        # Test for pkgbuild binary
        fail "pkgbuild must be installed." unless \
          File.exists?(PKGBUILD)

        make_directory_tree
        pack_source
        build_dmg
      end
      if @build.benchmark
        add_metrics({ :dist => 'osx', :bench => bench })
        post_metrics
      end
    puts "Finished building in: #{bench}"
    end
  end

  # An alias task to simplify our remote logic in jenkins.rake
  namespace :pl do
    task :dmg => "package:apple"
  end
end

