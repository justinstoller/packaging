module Packaging
  module Utils

    #######################################################
    #######################################################
    #  Begin Metrics section ( tasks/30_metrics.rake )
    #######################################################
    #######################################################
    @metrics          = []
    @pg_major_version = nil
    @db_table         = 'metrics'

    def add_metrics args
      @metrics << {
        :bench      => args[:bench],
        :dist       => ( args[:dist]        || ENV['DIST']       ),
        :pkg        => ( args[:pkg]         || @build.project    ),
        :version    => ( args[:version]     || @build.version    ),
        :pe_version => ( args[:pe_version]  || @build.pe_version ),
        :date       => ( args[:date]        || timestamp         ),
        :who        => ( args[:who]         || ENV['USER']       ),
        :where      => ( args[:where]       || hostname          )
      }
    end

    def post_metrics
      if psql = find_tool('psql')
        ENV["PGCONNECT_TIMEOUT"]="10"

        @metrics.each do |metric|
          date        = metric[:date]
          pkg         = metric[:pkg]
          dist        = metric[:dist]
          bench       = metric[:bench]
          who         = metric[:who]
          where       = metric[:where]
          version     = metric[:version]
          pe_version  = metric[:pe_version]
          @pg_major_version ||= %x{/usr/bin/psql --version}.match(/psql \(PostgreSQL\) (\d)\..*/)[1].to_i
          no_pass_fail = "-w" if @pg_major_version > 8
          %x{#{psql} #{no_pass_fail} -c "INSERT INTO #{@db_table} \
          (date, package, dist, build_time, build_user, build_loc, version, pe_version) \
          VALUES ('#{date}', '#{pkg}', '#{dist}', #{bench}, '#{who}', '#{where}', '#{version}', '#{pe_version}')"}
        end
        @metrics = []
      end
    end

    #######################################################
    #######################################################
    #  Begin Apple section ( tasks/apple.rake )
    #######################################################
    #######################################################

    # method:       make_directory_tree
    # description:  This method sets up the directory structure that packagemaker
    #               needs to build a package. A prototype.plist file (holding
    #               package-specific options) is built from an ERB template located
    #               in the ext/osx directory.
    def make_directory_tree
      project_tmp    = "#{get_temp}/#{@package_name}"
      @scratch       = "#{project_tmp}/#{@title}"
      @working_tree  = {
         'scripts'   => "#{@scratch}/scripts",
         'resources' => "#{@scratch}/resources",
         'working'   => "#{@scratch}/root",
         'payload'   => "#{@scratch}/payload",
      }
      puts "Cleaning Tree: #{project_tmp}"
      rm_rf(project_tmp)
      @working_tree.each do |key,val|
        mkdir_p(val)
      end

      if File.exists?('ext/osx/postflight.erb')
        erb 'ext/osx/postflight.erb', "#{@working_tree["scripts"]}/postinstall", @build.binding
      end

      if File.exists?('ext/osx/preflight.erb')
        erb 'ext/osx/preflight.erb', "#{@working_tree["scripts"]}/preinstall", @build.binding
      end

      if File.exists?('ext/osx/prototype.plist.erb')
        erb 'ext/osx/prototype.plist.erb', "#{@scratch}/prototype.plist", @build.binding
      end

      if File.exists?('ext/packaging/static_artifacts/PackageInfo.plist')
        cp 'ext/packaging/static_artifacts/PackageInfo.plist', "#{@scratch}/PackageInfo.plist", @build.binding
      end

    end

    # method:        build_dmg
    # description:   This method builds a package from the directory structure in
    #                /tmp/#{@project} and puts it in the
    #                /tmp/#{@project}/#{@project}-#{version}/payload directory. A DMG is
    #                created, using hdiutil, based on the contents of the
    #                /tmp/#{@project}/#{@project}-#{version}/payload directory. The resultant
    #                DMG is placed in the pkg/apple directory.
    #
    def build_dmg
      # Local Variables
      dmg_format_code   = 'UDZO'
      zlib_level        = '9'
      dmg_format_option = "-imagekey zlib-level=#{zlib_level}"
      dmg_format        = "#{dmg_format_code} #{dmg_format_option}"
      dmg_file          = "#{@title}.dmg"
      package_file      = "#{@title}.pkg"

      # Build .pkg file
      system("sudo #{PKGBUILD} --root #{@working_tree['working']} \
        --scripts #{@working_tree['scripts']} \
        --identifier #{@reverse_domain} \
        --version #{@version} \
        --install-location / \
        --ownership preserve \
        --info #{@scratch}/PackageInfo.plist \
        #{@working_tree['payload']}/#{package_file}")

      # Build .dmg file
      system("sudo hdiutil create -volname #{@title} \
        -srcfolder #{@working_tree['payload']} \
        -uid 99 \
        -gid 99 \
        -ov \
        -format #{dmg_format} \
        #{dmg_file}")

      if File.directory?("#{pwd}/pkg/apple")
        sh "sudo mv #{pwd}/#{dmg_file} #{pwd}/pkg/apple/#{dmg_file}"
        puts "moved:   #{dmg_file} has been moved to #{pwd}/pkg/apple/#{dmg_file}"
      else
        mkdir_p("#{pwd}/pkg/apple")
        sh "sudo mv #{pwd}/#{dmg_file} #{pwd}/pkg/apple/#{dmg_file}"
        puts "moved:   #{dmg_file} has been moved to #{pwd}/pkg/apple/#{dmg_file}"
      end
    end

    # method:        pack_source
    # description:   This method copies the #{@project} source into a directory
    #                structure in /tmp/#{@project}/#{@project}-#{version}/root mirroring the
    #                structure on the target system for which the package will be
    #                installed. Anything installed into /tmp/#{@project}/root will be
    #                installed as the package's payload.
    #
    def pack_source
      work          = "#{@working_tree['working']}"
      source = pwd

      # Make all necessary directories
      @source_files.each_value do |files|
        files.each_value do |params|
          mkdir_p "#{work}/#{params['path']}"
        end
      end

      # Install directory contents into place
      unless @source_files['directories'].nil?
        @source_files['directories'].each do |dir, params|
          unless FileList["#{source}/#{dir}/*"].empty?
            cmd = "#{DITTO} #{source}/#{dir}/ #{work}/#{params['path']}"
            puts cmd
            system(cmd)
          end
        end
      end

      # Setup a preinstall script and replace variables in the files with
      # the correct paths.
      if File.exists?("#{@working_tree['scripts']}/preinstall")
        chmod(0755, "#{@working_tree['scripts']}/preinstall")
        sh "sudo chown root:wheel #{@working_tree['scripts']}/preinstall"
      end

      # Setup a postinstall from from the erb created earlier
      if File.exists?("#{@working_tree['scripts']}/postinstall")
        chmod(0755, "#{@working_tree['scripts']}/postinstall")
        sh "sudo chown root:wheel #{@working_tree['scripts']}/postinstall"
      end

      # Do a run through first setting the specified permissions then
      # making sure 755 is set for all directories
      unless @source_files['directories'].nil?
        @source_files['directories'].each do |dir, params|
          owner = params['owner']
          group = params['group']
          perms = params['perms']
          path  = params['path']
          ##
          # Before setting our default permissions for all subdirectories/files of
          # each directory listed in directories, we have to get a list of the
          # directories. Otherwise, when we set the default perms (most likely
          # 0644) we'll lose traversal on subdirectories, and later when we want to
          # ensure they're 755 we won't be able to find them.
          #
          directories = []
          Dir["#{work}/#{path}/**/*"].each do |file|
            directories << file if File.directory?(file)
          end

          ##
          # Here we're setting the default permissions for all files as described
          # in file_mapping.yaml. Since we have a listing of directories, it
          # doesn't matter if we remove executable permission on directories, we'll
          # reset it later.
          #
          sh "sudo chmod -R #{perms} #{work}/#{path}"

          ##
          # We know at least one directory, the one listed in file_mapping.yaml, so
          # we set it executable.
          #
          sh "sudo chmod 0755 #{work}/#{path}"

          ##
          # Now that default perms are set, we go in and reset executable perms on
          # directories
          #
          directories.each { |d| sh "sudo chmod 0755 #{d}" }

          ##
          # Finally we set the owner/group as described in file_mapping.yaml
          #
          sh "sudo chown -R #{owner}:#{group} #{work}/#{path}"
        end
      end

      # Install any files
      unless @source_files['files'].nil?
        @source_files['files'].each do |file, params|
          owner = params['owner']
          group = params['group']
          perms = params['perms']
          dest  = params['path']
          # Allow for regexs like [A-Z]*
          FileList[file].each do |f|
            cmd = "sudo #{INSTALL} -o #{owner} -g #{group} -m #{perms} #{source}/#{f} #{work}/#{dest}"
            puts cmd
            system(cmd)
          end
        end
      end
    end


    #######################################################
    #######################################################
    #  Begin Deb section ( tasks/deb.rake )
    #######################################################
    #######################################################

    def pdebuild args
      results_dir = args[:work_dir]
      cow         = args[:cow]
      set_cow_envs(cow)
      update_cow(cow)
      sh "pdebuild  --configfile #{@build.pbuild_conf} \
                    --buildresult #{results_dir} \
                    --pbuilder cowbuilder -- \
                    --basepath /var/cache/pbuilder/#{cow}/"
      $?.success? or fail "Failed to build deb with #{cow}!"
    end

    def update_cow(cow)
      ENV['PATH'] = "/usr/sbin:#{ENV['PATH']}"
      set_cow_envs(cow)
      retry_on_fail(:times => 3) do
        sh "sudo -E /usr/sbin/cowbuilder --update --override-config --configfile #{@build.pbuild_conf} --basepath /var/cache/pbuilder/#{cow} --distribution #{ENV['DIST']} --architecture #{ENV['ARCH']}"
      end
    end

    def debuild args
      results_dir = args[:work_dir]
      begin
        sh "debuild --no-lintian -uc -us"
      rescue
        fail "Something went wrong. Hopefully the backscroll or #{results_dir}/#{@build.project}_#{@build.debversion}.build file has a clue."
      end
    end


    #######################################################
    #######################################################
    #  Begin Gem section ( tasks/gem.rake )
    #######################################################
    #######################################################

    def glob_gem_files
      gem_files = []
      gem_excludes_file_list = []
      gem_excludes_raw = @build.gem_excludes.nil? ? [] : @build.gem_excludes.split(' ')
      gem_excludes_raw << 'ext/packaging'
      gem_excludes_raw.each do |exclude|
        if File.directory?(exclude)
          gem_excludes_file_list += FileList["#{exclude}/**/*"]
        else
          gem_excludes_file_list << exclude
        end
      end
      files = FileList[@build.gem_files.split(' ')]
      files.each do |file|
        if File.directory?(file)
          gem_files += FileList["#{file}/**/*"]
        else
          gem_files << file
        end
      end
      gem_files = gem_files - gem_excludes_file_list
    end


    #######################################################
    #######################################################
    #  Begin Mock section ( tasks/mock.rake )
    #######################################################
    #######################################################

    # The mock methods/tasks are fairly specific to puppetlabs infrastructure, e.g., the mock configs
    # have to be named in a format like the PL mocks, e.g. dist-version-architecture, such as:
    # el-5-i386
    # fedora-17-i386
    # as well as the oddly formatted exception, 'pl-5-i386' which is the default puppetlabs FOSS mock
    # format for 'el-5-i386' (note swap 'pl' for 'el')
    #
    # The mock-built rpms are placed in a directory structure under 'pkg' based on how the Puppet Labs
    # repo structure is laid out in order to facilitate easy shipping from the local repository to the
    # Puppet Labs repos. For open source, the directory structure mirrors that of yum.puppetlabs.com:
    # pkg/<dist>/<version>/{products,devel,dependencies}/<arch>/*.rpm
    # e.g.,
    # pkg/el/5/products/i386/*.rpm
    # pkg/fedora/f16/products/i386/*.rpm
    #
    # For PE, the directory structure is flatter:
    # pkg/<dist>-<version>-<arch>/*.rpm
    # e.g.,
    # pkg/el-5-i386/*.rpm
    def mock_artifact(mock_config, cmd_args)
      unless mock = find_tool('mock')
        raise "mock is required for building srpms with mock. Please install mock and try again."
      end
      randomize = @build.random_mockroot
      configdir = nil
      basedir = File.join('var', 'lib', 'mock')

      if randomize
        basedir, configdir = randomize_mock_config_dir(mock_config)
        configdir_arg = " --configdir #{configdir}"
      end

      sh "#{mock} -r #{mock_config} #{configdir_arg} #{cmd_args}"
      # Clean up the configdir
      rm_r configdir unless configdir.nil?

      # Return a FileList of the build artifacts
      FileList[File.join(basedir, mock_config, 'result','*.rpm')]
    end

    # Use mock to build an SRPM
    # Return the path to the srpm
    def mock_srpm(mock_config, spec, sources, defines=nil)
      cmd_args = "--buildsrpm #{defines} --sources #{sources} --spec #{spec}"
      srpms = mock_artifact(mock_config, cmd_args)

      unless srpms.size == 1
        fail "#{srpms} contains an unexpected number of artifacts."
      end
      srpms[0]
    end

    # Use mock to build rpms from an srpm
    # Return a FileList containing the built RPMs
    def mock_rpm(mock_config, srpm)
      cmd_args = " #{srpm}"
      mock_artifact(mock_config, cmd_args)
    end

    # Determine the "family" of the target distribution based on the mock config name,
    # e.g. pupent-3.0-el5-i386 = "el"
    # and  pl-fedora-17-i386 = "fedora"
    #
    def mock_el_family(mock_config)
      if @build.build_pe
        family = mock_config.split('-')[2][/[a-z]+/]
      else
        first, second = mock_config.split('-')
        if (first == 'el' || first == 'fedora')
          family = first
        elsif first == 'pl'
          if second.match(/^\d+$/)
            family = 'el'
          else
            family = second
          end
        end
      end
      family
    end

    # Determine the major version of the target distribution based on the mock config name,
    # e.g. pupent-3.0-el5-i386 = "5"
    # and "pl-fedora-17-i386" = "17"
    #
    def mock_el_ver(mock_config)
      if @build.build_pe
        version = mock_config.split('-')[2][/[0-9]+/]
      else
        first, second, third = mock_config.split('-')
        if (first == 'el' || first == 'fedora') || (first == 'pl' && second.match(/^\d+$/))
          version = second
        else
          version = third
        end
      end
      if [first,second].include?('fedora')
        version = "f#{version}"
      end
      version
    end

    # Determine the appropriate rpm macro definitions based on the mock config name
    # Return a string of space separated macros prefixed with --define
    #
    def mock_defines(mock_config)
      family = mock_el_family(mock_config)
      version = mock_el_ver(mock_config)
      defines = ""
      if version =~ /^(4|5)$/ or family == "sles"
        defines = %Q{--define "%dist .#{family}#{version}" \
          --define "_source_filedigest_algorithm 1" \
          --define "_binary_filedigest_algorithm 1" \
          --define "_binary_payload w9.gzdio" \
          --define "_source_payload w9.gzdio" \
          --define "_default_patch_fuzz 2"}
      end
      defines
    end

    def build_rpm_with_mock(mocks)
      mocks.split(' ').each do |mock_config|
        family  = mock_el_family(mock_config)
        version = mock_el_ver(mock_config)
        subdir  = @build.is_rc? ? 'devel' : 'products'
        bench = Benchmark.realtime do
          # Set up the rpmbuild dir in a temp space, with our tarball and spec
          workdir = prep_rpm_build_dir
          spec = Dir.glob(File.join(workdir, "SPECS", "*.spec"))[0]
          sources = File.join(workdir, "SOURCES")
          defines = mock_defines(mock_config)

          # Build the srpm inside a mock chroot
          srpm = mock_srpm(mock_config, spec, sources, defines)

          # Now that we have the srpm, build the rpm in a mock chroot
          rpms = mock_rpm(mock_config, srpm)

          rpms.each do |rpm|
            rpm.strip!
            unless ENV['RC_OVERRIDE'] == '1'
              if @build.is_rc? == FALSE and rpm =~ /[0-9]+rc[0-9]+\./
                puts "It looks like you might be trying to ship an RC to the production repos. Leaving #{rpm}. Pass RC_OVERRIDE=1 to override."
                next
              elsif @build.is_rc? and rpm !~ /[0-9]+rc[0-9]+\./
                puts "It looks like you might be trying to ship a production release to the development repos. Leaving #{rpm}. Pass RC_OVERRIDE=1 to override."
                next
              end
            end

            if @build.build_pe
              %x{mkdir -p pkg/pe/rpm/#{family}-#{version}-{srpms,i386,x86_64}}
              case File.basename(rpm)
                when /debuginfo/
                  rm_rf(rpm)
                when /src\.rpm/
                  cp_pr(rpm, "pkg/pe/rpm/#{family}-#{version}-srpms")
                when /i.?86/
                  cp_pr(rpm, "pkg/pe/rpm/#{family}-#{version}-i386")
                when /x86_64/
                  cp_pr(rpm, "pkg/pe/rpm/#{family}-#{version}-x86_64")
                when /noarch/
                  cp_pr(rpm, "pkg/pe/rpm/#{family}-#{version}-i386")
                  ln("pkg/pe/rpm/#{family}-#{version}-i386/#{File.basename(rpm)}", "pkg/pe/rpm/#{family}-#{version}-x86_64/")
              end
            else
              %x{mkdir -p pkg/#{family}/#{version}/#{subdir}/{SRPMS,i386,x86_64}}
              case File.basename(rpm)
                when /debuginfo/
                  rm_rf(rpm)
                when /src\.rpm/
                  cp_pr(rpm, "pkg/#{family}/#{version}/#{subdir}/SRPMS")
                when /i.?86/
                  cp_pr(rpm, "pkg/#{family}/#{version}/#{subdir}/i386")
                when /x86_64/
                  cp_pr(rpm, "pkg/#{family}/#{version}/#{subdir}/x86_64")
                when /noarch/
                  cp_pr(rpm, "pkg/#{family}/#{version}/#{subdir}/i386")
                  ln("pkg/#{family}/#{version}/#{subdir}/i386/#{File.basename(rpm)}", "pkg/#{family}/#{version}/#{subdir}/x86_64/")
              end
            end
          end
          # To avoid filling up the system with our random mockroots, we should
          # clean up. However, this requires sudo. If we don't have sudo, we'll
          # just fail and not clean up, but warn the user about it.
          if @build.random_mockroot
            %x{sudo -n echo 'Cleaning build root.'}
            if $?.success?
              sh "sudo -n rm -r #{File.dirname(srpm)}" unless File.dirname(srpm).nil?
              sh "sudo -n rm -r #{File.dirname(rpms[0])}" unless File.dirname(rpms[0]).nil?
              sh "sudo -n rm -r #{workdir}" unless workdir.nil?
            else
              warn "Couldn't clean rpm build areas without sudo. Leaving."
            end
          end
        end
        add_metrics({ :dist => "#{family}-#{version}", :bench => bench }) if @build.benchmark
        puts "Finished building in: #{bench}"
      end
    end

    # With the advent of using Jenkins to parallelize builds, it becomes critical
    # that we be able to use the same mock at the same time for > 1 builds without
    # clobbering the mock root every time. Here we add a method that takes the full
    # path to a mock configuration and a path, and adds a base directory
    # configuration directive to the mock to use the path as the directory for the
    # mock build root. The new mock config is written to a temporary space, and its
    # location is returned.  This allows us to create mock configs with randomized
    # temporary mock roots.
    #
    def mock_with_basedir(mock, basedir)
      config = IO.readlines(mock)
      basedir = "config_opts['basedir'] = '#{basedir}'"
      config.unshift(basedir)
      tempdir = get_temp
      newmock = File.join(tempdir, File.basename(mock))
      File.open(newmock, 'w') { |f| f.puts config }
      newmock
    end

    # Mock accepts an alternate configuration directory to /etc/mock for mock
    # configs, but the directory has to include both site-defaults.cfg and
    # logging.ini. This is a simple utility method to set a mock configuration dir
    # by copying a mock and the required defaults to a temporary directory and
    # returning that directory. This method takes the full path to a mock
    # configuration file and returns the path to the new configuration dir.
    #
    def setup_mock_config_dir(mock)
      tempdir = get_temp
      cp File.join('/', 'etc', 'mock', 'site-defaults.cfg'), tempdir
      cp File.join('/', 'etc', 'mock', 'logging.ini'), tempdir
      cp mock, tempdir
      tempdir
    end

    # Create a mock config file from an existing one, except insert the 'basedir'
    # option. 'basedir' will be set to a random directory we create. Move the new
    # mock config and the required default mock settings files into a new config
    # dir to pass to mock. Return the path to the config dir.
    #
    def randomize_mock_config_dir(mock_config)
      # basedir will be the location of our temporary mock root
      basedir = get_temp
      chown("#{ENV['USER']}", "mock", basedir)
      # Mock requires the sticky bit be set on the basedir
      chmod(02775, basedir)
      mockfile = File.join('/', 'etc', 'mock', "#{mock_config}.cfg")
      puts "Setting mock basedir to #{basedir}"
      # Create a new mock config file with 'basedir' set to our basedir
      config = mock_with_basedir(mockfile, basedir)
      # Setup a mock config dir, copying in our mock config and logging.ini etc
      configdir = setup_mock_config_dir(config)
      # Clean up the directory with the temporary mock config
      rm_r File.dirname(config)
      return basedir, configdir
    end


    #######################################################
    #######################################################
    #  Begin PRM section ( tasks/rpm.rake )
    #######################################################
    #######################################################

    def prep_rpm_build_dir
      temp = get_temp
      mkdir_pr temp, "#{temp}/SOURCES", "#{temp}/SPECS"
      cp_pr FileList["pkg/#{@build.project}-#{@build.version}.tar.gz*"], "#{temp}/SOURCES"
      erb "ext/redhat/#{@build.project}.spec.erb", "#{temp}/SPECS/#{@build.project}.spec", @build.binding
      temp
    end

    def build_rpm(buildarg = "-bs")
      check_tool('rpmbuild')
      workdir = prep_rpm_build_dir
      if dist = el_version
        if dist.to_i < 6
          dist_string = "--define \"%dist .el#{dist}"
        end
      end
      rpm_define = "#{dist_string} --define \"%_topdir  #{workdir}\" "
      rpm_old_version = '--define "_source_filedigest_algorithm 1" --define "_binary_filedigest_algorithm 1" \
         --define "_binary_payload w9.gzdio" --define "_source_payload w9.gzdio" \
         --define "_default_patch_fuzz 2"'
      args = rpm_define + ' ' + rpm_old_version
      mkdir_pr 'pkg/srpm'
      if buildarg == '-ba'
        mkdir_p 'pkg/rpm'
      end
      if @build.sign_tar
        Rake::Task["pl:sign_tar"].invoke
      end
      sh "rpmbuild #{args} #{buildarg} --nodeps #{workdir}/SPECS/#{@build.project}.spec"
      mv FileList["#{workdir}/SRPMS/*.rpm"], "pkg/srpm"
      if buildarg == '-ba'
        mv FileList["#{workdir}/RPMS/*/*.rpm"], "pkg/rpm"
      end
      rm_rf workdir
      puts
      output = FileList['pkg/*/*.rpm']
      puts "Wrote:"
      output.each do | line |
        puts line
      end
    end


    #######################################################
    #######################################################
    #  Begin Signing section ( tasks/sign.rake )
    #######################################################
    #######################################################

    def sign_el5(rpm)
      # Try this up to 5 times, to allow for incorrect passwords
      retry_on_fail(:times => 5) do
        sh "rpm --define '%_gpg_name #{@build.gpg_name}' --define '%__gpg_sign_cmd %{__gpg} gpg --force-v3-sigs --digest-algo=sha1 --batch --no-verbose --no-armor --passphrase-fd 3 --no-secmem-warning -u %{_gpg_name} -sbo %{__signature_filename} %{__plaintext_filename}' --addsign #{rpm} > /dev/null"
      end
    end

    def sign_modern(rpm)
      retry_on_fail(:times => 5) do
        sh "rpm --define '%_gpg_name #{@build.gpg_name}' --addsign #{rpm} > /dev/null"
      end
    end

    def rpm_has_sig(rpm)
      %x{rpm -Kv #{rpm} | grep "#{@build.gpg_key.downcase}" &> /dev/null}
      $?.success?
    end

    def sign_deb_changes(file)
      %x{debsign --re-sign -k#{@build.gpg_key} #{file}}
    end

    # requires atleast a self signed prvate key and certificate pair
    # fmri is the full IPS package name with version, e.g.
    # facter@facter@1.6.15,5.11-0:20121112T042120Z
    # technically this can be any ips-compliant package identifier, e.g. application/facter
    # repo_uri is the path to the repo currently containing the package
    def sign_ips(fmri, repo_uri)
      %x{pkgsign -s #{repo_uri}  -k #{@build.privatekey_pem} -c #{@build.certificate_pem} -i #{@build.ips_inter_cert} #{fmri}}
    end


    #######################################################
    #######################################################
    #  Begin Signing section ( tasks/sign.rake )
    #######################################################
    #######################################################


    def check_tool(tool)
      return true if has_tool(tool)
      fail "#{tool} tool not found...exiting"
    end

    def find_tool(tool)
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |root|
        location = File.join(root, tool)
        return location if FileTest.executable? location
      end
      return nil
    end
    alias :has_tool :find_tool

    def check_file(file)
      File.exist?(file) or fail "#{file} file not found!"
    end

    def check_var(varname,var=nil)
      var.nil? and fail "Requires #{varname} be set!"
    end

    def check_host(host)
      host == %x{hostname}.chomp! or fail "Requires host to be #{host}!"
    end

    def erb_string(erbfile, context = binding)
      template  = File.read(erbfile)
      message   = ERB.new(template, nil, "-")
      message.result( context )
    end

    def erb(erbfile,  outfile, context = binding)
      output           = erb_string(erbfile, context)
      File.open(outfile, 'w') { |f| f.write output }
      puts "Generated: #{outfile}"
    end

    def cp_pr(src, dest, options={})
      mandatory = {:preserve => true}
      cp_r(src, dest, options.merge(mandatory))
    end

    def cp_p(src, dest, options={})
      mandatory = {:preserve => true}
      cp(src, dest, options.merge(mandatory))
    end

    def mv_f(src, dest, options={})
      mandatory = {:force => true}
      mv(src, dest, options.merge(mandatory))
    end

    def git_co(ref)
      %x{git reset --hard ; git checkout #{ref}}
      $?.success? or fail "Could not checkout #{ref} git branch to build package from...exiting"
    end

    def get_temp
      `mktemp -d -t pkgXXXXXX`.strip
    end

    def remote_ssh_cmd target, command
      check_tool('ssh')
      puts "Executing '#{command}' on #{target}"
      sh "ssh -t #{target} '#{command.gsub("'", "'\\\\''")}'"
    end

    def rsync_to *args
      check_tool('rsync')
      flags = "-rHlv -O --no-perms --no-owner --no-group"
      source  = args[0]
      target  = args[1]
      dest    = args[2]
      puts "rsyncing #{source} to #{target}"
      sh "rsync #{flags} #{source} #{target}:#{dest}"
    end

    def rsync_from *args
      check_tool('rsync')
      flags = "-rHlv -O --no-perms --no-owner --no-group"
      source  = args[0]
      target  = args[1]
      dest    = args[2]
      puts "rsyncing #{source} from #{target} to #{dest}"
      sh "rsync #{flags} #{target}:#{source} #{dest}"
    end

    def scp_file_from(host,path,file)
      %x{scp #{host}:#{path}/#{file} #{@tempdir}/#{file}}
    end

    def scp_file_to(host,path,file)
      %x{scp #{@tempdir}/#{file} #{host}:#{path}}
    end

    def timestamp(separator=nil)
      if s = separator
        format = "%Y#{s}%m#{s}%d#{s}%H#{s}%M#{s}%S"
      else
        format = "%Y-%m-%d %H:%M:%S"
      end
      Time.now.strftime(format)
    end

    def load_keychain
      unless @keychain_loaded
        kill_keychain
        start_keychain
        @keychain_loaded = TRUE
      end
    end

    def source_dirty?
      git_describe_version.include?('dirty')
    end

    def fail_on_dirty_source
      if source_dirty?
        fail "
    The source tree is dirty, e.g. there are uncommited changes. Please
    commit/discard changes and try again."
      end
    end

    def kill_keychain
      %x{keychain -k mine}
    end

    def start_keychain
      keychain = %x{/usr/bin/keychain -q --agents gpg --eval #{@build.gpg_key}}.chomp
      new_env = keychain.match(/(GPG_AGENT_INFO)=([^;]*)/)
      ENV[new_env[1]] = new_env[2]
    end

    def gpg_sign_file(file)
      gpg ||= find_tool('gpg')

      if gpg
        sh "#{gpg} --armor --detach-sign -u #{@build.gpg_key} #{file}"
      else
        fail "No gpg available. Cannot sign #{file}."
      end
    end

    def mkdir_pr *args
      args.each do |arg|
        mkdir_p arg
      end
    end

    def set_cow_envs(cow)
      elements = cow.split('-')
      if elements.size != 3
        fail "Expecting a cow name split on hyphens, e.g. 'base-squeeze-i386'"
      else
        dist = elements[1]
        arch = elements[2]
        if dist.nil? or arch.nil?
          fail "Couldn't get the arg and dist from cow name. Expecting something like 'base-dist-arch'"
        end
        arch = arch.split('.')[0] if arch.include?('.')
      end
      if @build.build_pe
        ENV['PE_VER'] = @build.pe_version
      end
      ENV['DIST'] = dist
      ENV['ARCH'] = arch
    end

    def ln(target, name)
      FileUtils.ln(name, target, :force => true, :verbose => true)
    end

    def ln_sfT(src, dest)
      sh "ln -sfT #{src} #{dest}"
    end

    def git_commit_file(file, message=nil)
      if has_tool('git') and File.exist?('.git')
        message ||= "changes"
        puts "Commiting changes:"
        puts
        diff = %x{git diff HEAD #{file}}
        puts diff
        %x{git commit #{file} -m "Commit #{message} in #{file}" &> /dev/null}
      end
    end

    def ship_gem(file)
      %x{gem push #{file}}
    end

    def ask_yes_or_no
      return boolean_value(ENV['ANSWER_OVERRIDE']) unless ENV['ANSWER_OVERRIDE'].nil?
      answer = STDIN.gets.downcase.chomp
      return TRUE if answer =~ /^y$|^yes$/
      return FALSE if answer =~ /^n$|^no$/
      puts "Nope, try something like yes or no or y or n, etc:"
      ask_yes_or_no
    end

    def handle_method_failure(method, args)
      STDERR.puts "There was an error running the method #{method} with the arguments:"
      args.each { |param, arg| STDERR.puts "\t#{param} => #{arg}\n" }
      STDERR.puts "The rake session is paused. Would you like to retry #{method} with these args and continue where you left off? [y,n]"
      if ask_yes_or_no
        send(method, args)
      else
        exit 1
      end
    end

    def invoke_task(task, args=nil)
      Rake::Task[task].reenable
      Rake::Task[task].invoke(args)
    end

    def confirm_ship(files)
      STDOUT.puts "The following files have been built and are ready to ship:"
      files.each { |file| STDOUT.puts "\t#{file}\n" unless File.directory?(file) }
      STDOUT.puts "Ship these files?? [y,n]"
      ask_yes_or_no
    end

    def boolean_value(var)
      return TRUE if (var == TRUE || ( var.is_a?(String) && ( var.downcase == 'true' || var.downcase =~ /^y$|^yes$/ )))
      FALSE
    end

    def git_tag(version)
      sh "git tag -s -u #{@build.gpg_key} -m '#{version}' #{version}"
      $?.success or fail "Unable to tag repo at #{version}"
    end

    def rand_string
      rand.to_s.split('.')[1]
    end

    def git_bundle(treeish)
      temp = get_temp
      appendix = rand_string
      sh "git bundle create #{temp}/#{@build.project}-#{@build.version}-#{appendix} #{treeish} --tags"
      cd temp do
        sh "tar -czf #{@build.project}-#{@build.version}-#{appendix}.tar.gz #{@build.project}-#{@build.version}-#{appendix}"
        rm_rf "#{@build.project}-#{@build.version}-#{appendix}"
      end
      "#{temp}/#{@build.project}-#{@build.version}-#{appendix}.tar.gz"
    end

    # We take a tar argument for cases where `tar` isn't best, e.g. Solaris
    def remote_bootstrap(host, treeish, tar_cmd=nil)
      unless tar = tar_cmd
        tar = 'tar'
      end
      tarball = git_bundle(treeish)
      tarball_name = File.basename(tarball).gsub('.tar.gz','')
      rsync_to(tarball, host, '/tmp')
      appendix = rand_string
      sh "ssh -t #{host} '#{tar} -zxvf /tmp/#{tarball_name}.tar.gz -C /tmp/ ; git clone --recursive /tmp/#{tarball_name} /tmp/#{@build.project}-#{appendix} ; cd /tmp/#{@build.project}-#{appendix} ; rake package:bootstrap'"
      "/tmp/#{@build.project}-#{appendix}"
    end

    # Given a BuildInstance object and a host, send its params to the host. Return
    # the remote path to the params.
    def remote_buildparams(host, build)
      params_file = build.params_to_yaml
      params_file_name = File.basename(params_file)
      params_dir = rand_string
      rsync_to(params_file, host, "/tmp/#{params_dir}/")
      "/tmp/#{params_dir}/#{params_file_name}"
    end

    def is_git_repo
      %x{git rev-parse --git-dir > /dev/null 2>&1}
      return $?.success?
    end

    def git_pull(remote, branch)
      sh "git pull #{remote} #{branch}"
    end

    def create_rpm_repo(dir)
      check_tool('createrepo')
      cd dir do
        sh "createrepo -d ."
      end
    end

    def update_rpm_repo(dir)
      check_tool('createrepo')
      cd dir do
        sh "createrepo -d --update ."
      end
    end

    def empty_dir?(dir)
      File.exist?(dir) and File.directory?(dir) and Dir["#{dir}/**/*"].empty?
    end

    def hostname
      require 'socket'
      Socket.gethostname
    end

    # Loop a block up to the number of attempts given, exiting when we receive success
    # or max attempts is reached. Raise an exception unless we've succeeded.
    def retry_on_fail(args, &blk)
      success = FALSE
      if args[:times].respond_to?(:times) and block_given?
        args[:times].times do |i|
          begin
            blk.call
            success = TRUE
            break
          rescue
            puts "An error was encountered evaluating block. Retrying.."
          end
        end
      else
        fail "retry_on_fail requires and arg (:times => x) where x is an Integer/Fixnum, and a block to execute"
      end
      fail "Block failed maximum of #{args[:times]} tries. Exiting.." unless success
    end

    def deprecate(old_cmd, new_cmd=nil)
      msg = "!! #{old_cmd} is deprecated."
      if new_cmd
        msg << " Please use #{new_cmd} instead."
      end
      STDOUT.puts
      STDOUT.puts(msg)
      STDOUT.puts
    end

    # Utility method to return the dist method if this is a redhat box. We use this
    # in rpm packaging to define a dist macro, and we use it in the pl:fetch task
    # to disable ssl checking for redhat 5 because it has a certs bundle so old by
    # default that it's useless for our purposes.
    def el_version()
      if File.exists?('/etc/fedora-release')
        nil
      elsif File.exists?('/etc/redhat-release')
        return %x{rpm -q --qf \"%{VERSION}\" $(rpm -q --whatprovides /etc/redhat-release )}
      end
    end

    # Given the path to a yaml file, load the yaml file into an object and return
    # the object.
    def data_from_yaml(file)
      file = File.expand_path(file)
      begin
        input_data = YAML.load_file(file) || {}
      rescue => e
        STDERR.puts "There was an error loading data from #{file}."
        fail e.backtrace.join("\n")
      end
      input_data
    end

    # This is fairly absurd. We're implementing curl by shelling out. What do I
    # wish we were doing? Using a sweet ruby wrapper around curl, such as Curb or
    # Curb-fu. However, because we're using clean build systems and trying to
    # make this portable with minimal system requirements, we can't very well
    # depend on libraries that aren't in the ruby standard libaries. We could
    # also do this using Net::HTTP but that set of libraries is a rabbit hole to
    # go down when what we're trying to accomplish is posting multi-part form
    # data that includes file uploads to jenkins. It gets hairy fairly quickly,
    # but, as they say, pull requests accepted.
    #
    # This method takes two arguments
    # 1) String - the URL to post to
    # 2) Array  - Ordered array of name=VALUE curl form parameters
    def curl_form_data(uri, form_data=[], options={})
      curl = find_tool("curl") or fail "Couldn't find curl. Curl is required for posting jenkins to trigger a build. Please install curl and try again."
      #
      # Begin constructing the post string.
      # First, assemble the form_data arguments
      #
      post_string = "-i "
      form_data.each do |param|
        post_string << "#{param} "
      end

      # Add the uri
      post_string << "#{uri}"

      # If this is quiet, we're going to silence all output
      if options[:quiet]
        post_string << " >/dev/null 2>&1"
      end

      %x{#{curl} #{post_string}}
      return $?.success?
    end

    def random_string length
      rand(36**length).to_s(36)
    end

    # Use the curl to create a jenkins job from a valid XML
    # configuration file.
    # Returns the URL to the job
    def create_jenkins_job(name, xml_file)
      create_url = "http://#{@build.jenkins_build_host}/createItem?name=#{name}"
      form_args = ["-H", '"Content-Type: application/xml"', "--data-binary", "@#{xml_file}"]
      curl_form_data(create_url, form_args)
      "http://#{@build.jenkins_build_host}/job/#{name}"
    end

    # Use the curl to check of a named job is defined on the jenkins server.  We
    # curl the config file rather than just checking if the job exists by curling
    # the job url and passing --head because jenkins will mistakenly return 200 OK
    # if you issue multiple very fast requests just requesting the header.
    def jenkins_job_exists?(name)
      job_url = "http://#{@build.jenkins_build_host}/job/#{name}/config.xml"
      form_args = ["--silent", "--fail"]
      curl_form_data(job_url, form_args, :quiet => true)
    end

    def require_library_or_fail(library)
      begin
        require library
      rescue LoadError
        fail "Could not load #{library}. #{library} is required by the packaging repo for this task"
      end
    end

    # Use the provided URL string to print important information with
    # ASCII emphasis
    def print_url_info(url_string)
    puts "\n////////////////////////////////////////////////////////////////////////////////\n\n
      Build submitted. To view your build progress, go to\n#{url_string}\n\n
    ////////////////////////////////////////////////////////////////////////////////\n\n"
    end

    def escape_html(uri)
      require 'cgi'
      CGI.escapeHTML(uri)
    end
  end
end
