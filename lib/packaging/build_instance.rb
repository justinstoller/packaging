module Packaging
  ##
  # This class is meant to encapsulate all of the data we know about a build invoked with
  # `rake package:<build>` or `rake pl:<build>`. It can read in this data via a yaml file,
  # have it set via accessors, and serialize it back to yaml for easy transport.
  #
  class BuildInstance
    include Packaging::Utils

    @@build_params = [:apt_host,
                      :apt_repo_path,
                      :apt_repo_url,
                      :author,
                      :benchmark,
                      :build_date,
                      :build_defaults,
                      :build_dmg,
                      :build_doc,
                      :build_gem,
                      :build_ips,
                      :build_pe,
                      :builder_data_file,
                      :builds_server,
                      :certificate_pem,
                      :cows,
                      :db_table,
                      :deb_build_host,
                      :debversion,
                      :debug,
                      :default_cow,
                      :default_mock,
                      :description,
                      :distribution_server,
                      :dmg_path,
                      :email,
                      :files,
                      :final_mocks,
                      :freight_conf,
                      :gem_default_executables,
                      :gem_dependencies,
                      :gem_description,
                      :gem_devel_dependencies,
                      :gem_excludes,
                      :gem_executables,
                      :gem_files,
                      :gem_forge_project,
                      :gem_name,
                      :gem_rdoc_options,
                      :gem_require_path,
                      :gem_runtime_dependencies,
                      :gem_summary,
                      :gem_test_files,
                      :gemversion,
                      :gpg_key,
                      :gpg_name,
                      :homepage,
                      :ips_build_host,
                      :ips_host,
                      :ips_inter_cert,
                      :ips_package_host,
                      :ips_path,
                      :ips_repo,
                      :ips_store,
                      :ipsversion,
                      :jenkins_build_host,
                      :jenkins_packaging_job,
                      :jenkins_repo_path,
                      :metrics,
                      :metrics_url,
                      :name,
                      :notify,
                      :project,
                      :origversion,
                      :osx_build_host,
                      :packager,
                      :packaging_repo,
                      :packaging_url,
                      :pbuild_conf,
                      :pe_name,
                      :pe_version,
                      :pg_major_version,
                      :pre_tar_task,
                      :privatekey_pem,
                      :random_mockroot,
                      :rc_mocks,
                      :release,
                      :rpm_build_host,
                      :rpmrelease,
                      :rpmversion,
                      :ref,
                      :sign_tar,
                      :summary,
                      :tar_excludes,
                      :tar_host,
                      :tarball_path,
                      :task,
                      :team,
                      :version,
                      :version_file,
                      :yum_host,
                      :yum_repo_path]

    @@build_params.each do |v|
      attr_accessor v
    end

    def initialize
      @task              = { :task => $*[0], :args => $*[1..-1] }
      @ref               =  git_sha_or_tag
      @builder_data_file = 'builder_data.yaml'
      @random_mockroot   =  ENV['RANDOM_MOCKROOT'] ? boolean_value(ENV['RANDOM_MOCKROOT']) : true
      @keychain_loaded   =  FALSE
      @build_root        =  Dir.pwd
      @build_date        =  timestamp('-')
    end
    alias name project

    ##
    # Take a hash of parameters, and iterate over them,
    # setting each build param to the corresponding hash key,value.
    #
    def set_params_from_hash(data = {})
      data.each do |param, value|
        if @@build_params.include?(param.to_sym)
          self.instance_variable_set("@#{param}", value)
        else
          warn "Warning - No build data parameter found for '#{param}'. Perhaps you have an erroneous entry in your yaml file?"
        end
      end
    end

    ##
    # Load build parameters from a yaml file. Uses #data_from_yaml in
    # 00_utils.rake
    #
    def set_params_from_file(file)
      build_data = data_from_yaml(file)
      set_params_from_hash(build_data)
    end

    ##
    # Return a hash of all build parameters and their values, nil if unassigned.
    #
    def params
      data = {}
      @@build_params.each do |param|
        data.store(param, self.instance_variable_get("@#{param}"))
      end
      data
    end

    # Allow environment variables to override the settings we just read in. These
    # variables are called out specifically because they are likely to require
    # overriding in at least some cases.
    #
    def override_params_with_environment
      sign_tar        = boolean_value(ENV['SIGN_TAR']) if ENV['SIGN_TAR']
      build_gem       = boolean_value(ENV['GEM'])      if ENV['GEM']
      build_dmg       = boolean_value(ENV['DMG'])      if ENV['DMG']
      build_ips       = boolean_value(ENV['IPS'])      if ENV['IPS']
      build_doc       = boolean_value(ENV['DOC'])      if ENV['DOC']
      build_pe        = boolean_value(ENV['PE_BUILD']) if ENV['PE_BUILD']
      debug           = boolean_value(ENV['DEBUG'])    if ENV['DEBUG']
      default_cow     = ENV['COW']                     if ENV['COW']
      cows            = ENV['COW']                     if ENV['COW']
      pbuild_conf     = ENV['PBUILDCONF']              if ENV['PBUILDCONF']
      packager        = ENV['PACKAGER']                if ENV['PACKAGER']
      default_mock    = ENV['MOCK']                    if ENV['MOCK']
      final_mocks     = ENV['MOCK']                    if ENV['MOCK']
      rc_mocks        = ENV['MOCK']                    if ENV['MOCK']
      gpg_name        = ENV['GPG_NAME']                if ENV['GPG_NAME']
      gpg_key         = ENV['GPG_KEY']                 if ENV['GPG_KEY']
      certificate_pem = ENV['CERT_PEM']                if ENV['CERT_PEM']
      privatekey_pem  = ENV['PRIVATE_PEM']             if ENV['PRIVATE_PEM']
      yum_host        = ENV['YUM_HOST']                if ENV['YUM_HOST']
      yum_repo_path   = ENV['YUM_REPO']                if ENV['YUM_REPO']
      apt_host        = ENV['APT_HOST']                if ENV['APT_HOST']
      apt_repo_path   = ENV['APT_REPO']                if ENV['APT_REPO']
      pe_version      = ENV['PE_VER']                  if ENV['PE_VER']
      notify          = ENV['NOTIFY']                  if ENV['NOTIFY']
    end

    ##
    # Write all build parameters to a yaml file in a temporary location. Print
    # the path to the file and return it as a string. Accept an argument for
    # the write target directory. The name of the params file is the current
    # git commit sha or tag.
    #
    def params_to_yaml(output_dir=nil)
      dir = output_dir.nil? ? get_temp : output_dir
      File.writable?(dir) or fail "#{dir} does not exist or is not writable, skipping build params write. Exiting.."
      params_file = File.join(dir, "#{self.ref}.yaml")
      File.open(params_file, 'w') do |f|
        f.puts params.to_yaml
      end
      puts params_file
      params_file
    end

    ##
    # Print the names and values of all the params known to the build object
    #
    def print_params
      params.each { |k,v| puts "#{k}: #{v}" }
    end

    # Determines if this package is an rc package via the version
    # returned by get_dash_version method.
    # Assumes version strings in the formats:
    # final:
    # '0.7.0'
    # '0.7.0-63'
    # '0.7.0-63-dirty'
    # rc:
    # '0.7.0rc1 (we don't actually use this format anymore, but once did)
    # '0.7.0-rc1'
    # '0.7.0-rc1-63'
    # '0.7.0-rc1-63-dirty'
    def is_rc?
      return TRUE if dash_version =~ /^\d+\.\d+\.\d+-*rc\d+/
      FALSE
    end

    def git_describe
      %x{git describe}.strip
    end

    # return the sha of HEAD on the current branch
    def git_sha
      %x{git rev-parse HEAD}.strip
    end

    # Return the ref type of HEAD on the current branch
    def git_ref_type
      %x{git cat-file -t #{git_describe}}.strip
    end

    # If HEAD is a tag, return the tag. Otherwise return the sha of HEAD.
    def git_sha_or_tag
      if git_ref_type == "tag"
        git_describe
      else
        git_sha
      end
    end

    #
    # Accessors
    #
    def dash_version
      @dash_version ||= git_version ? git_version.join('-') : pwd_version
    end
    alias version dash_version

    def dot_version
      @dot_version ||= get_dot_version
    end
    alias gem_version dot_version
    alias gemversion  dot_version

    def deb_version
      @deb_version ||= get_deb_version
    end
    alias debversion deb_version

    def git_version
      @git_version ||= get_git_version
    end

    def ips_version
      @ips_version ||= get_ips_version
    end
    alias ipsversion ips_version

    def pwd_version
      @pwd_version ||= get_pwd_version
    end

    def release
      @release ||= ENV['RELEASE'] || '1'
    end

    def rpm_version
      @rpm_version ||= base_version[0]
    end
    alias rpmversion   rpm_version
    alias origversion  rpm_version
    alias orig_version rpm_version

    def rpm_release
      @rpm_release ||= base_version[1]
    end
    alias rpmrelease rpm_release

    def team
      @team ||= ENV['TEAM'] || 'dev'
    end

    def base_version
      @base_version ||= get_base_version
    end

    def get_ips_version
      if git_version
        version, commits, dirty = *git_version
        if commits.to_s.match('^rc[\d]+')
          commits = git_version[2]
          dirty   = git_version[3]
        end

        osrelease = uname_r
        "#{version},#{osrelease}-#{commits.to_i}#{dirty ? '-dirty' : ''}"
      else

        pwd_version
      end
    end

    def get_base_version
      if dash_version.include? 'rc'
        # Grab the rc number
        rc_num = dash_version.match(/rc(\d+)/)[1]
        # MetaGSubbing???
        ver = dash_version.sub( /-?rc[0-9]+/,
                                "-0.#{release}rc#{rc_num}").gsub( /(rc[0-9]+)-(\d+)?-?/,
                                                                  '\1.\2')
      else
        ver = dash_version.gsub('-','.') + "-#{release}"
      end

      ver.split('-')
    end

    def get_deb_version
      base_version.join('-') << "#{packager}1"
    end

    def get_dot_version
      dash_version.gsub('-', '.')
    end

    def get_pwd_version
      %x{pwd}.strip.split('.')[-1]
    end

    # Return information about the current tree, using `git describe`, ready for
    # further processing.
    #
    # Returns an array of one to four elements, being:
    # * version (three dot-joined numbers, leading `v` stripped)
    # * the string 'rcX' (if the last tag was an rc release, where X is the rc number)
    # * commits (string containing integer, number of commits since that version was tagged)
    # * dirty (string 'dirty' if local changes exist in the repo)
    def get_git_version
      return nil unless is_git_repo and raw = git_describe_internal
      # reprocess that into a nice set of output data
      # The elements we select potentially change if this is an rc
      # For an rc with added commits our string will be something like '0.7.0-rc1-63-g51ccc51'
      # and our return will be [0.7.0, rc1, 63, <dirty>]
      # For a final with added commits, it will look like '0.7.0-63-g51ccc51'
      # and our return will be [0.7.0, 64, <dirty>]
      info = raw.chomp.sub(/^v/, '').split('-')
      if info[1].to_s.match('^[\d]+')
        version_string = info.values_at(0,1,3).compact
      else
        version_string = info.values_at(0,1,2,4).compact
      end
      version_string
    end

    # This is a stub to ease testing...
    def git_describe_internal
      raw = %x{git describe --tags --dirty 2>/dev/null}
      $?.success? ? raw : nil
    end

    def uname_r
      %x{uname -r}.chomp
    end
  end
end
