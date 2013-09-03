# -*- ruby -*-
require 'spec_helper'
require 'packaging/utils'
require 'packaging/build_instance'
require 'yaml'

Build_Params = [
  :apt_host,
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
  :yum_repo_path
]

TestVersions = {
  '0.7.0' => {
    :git_version  => %w{0.7.0},
    :dash_version => '0.7.0',
    :ips_version  => '0.7.0,3.14159-0',
    :dot_version  => '0.7.0',
    :deb_version  => '0.7.0-1puppetlabs1',
    :rpm_version  => '0.7.0',
    :rpm_release  => '1',
    :is_rc?       =>  false,
  },
  '0.7.0rc10' => {
    :git_version  =>   %w{0.7.0rc10},
    :dash_version => '0.7.0rc10',
    :ips_version  => '0.7.0rc10,3.14159-0',
    :dot_version  => '0.7.0rc10',
    :deb_version  => '0.7.0-0.1rc10puppetlabs1',
    :rpm_version  => '0.7.0',
    :rpm_release  => '0.1rc10',
    :is_rc?       =>  true,
  },
  '0.7.0-rc1' => {
    :git_version  => %w{0.7.0 rc1},
    :dash_version => '0.7.0-rc1',
    :ips_version  => '0.7.0,3.14159-0',
    :dot_version  => '0.7.0.rc1',
    :deb_version  => '0.7.0-0.1rc1puppetlabs1',
    :rpm_version  => '0.7.0',
    :rpm_release  => '0.1rc1',
    :is_rc?       =>  true,
  },
  '0.7.0-rc1-63-ge391f55' => {
    :git_version  => %w{0.7.0 rc1 63},
    :dash_version => '0.7.0-rc1-63',
    :ips_version  => '0.7.0,3.14159-63',
    :dot_version  => '0.7.0.rc1.63',
    :deb_version  => '0.7.0-0.1rc1.63puppetlabs1',
    :rpm_version  => '0.7.0',
    :rpm_release  => '0.1rc1.63',
    :is_rc?       =>  true,
  },
  '0.7.0-rc1-63-ge391f55-dirty' => {
    :git_version  => %w{0.7.0 rc1 63 dirty},
    :dash_version => '0.7.0-rc1-63-dirty',
    :ips_version  => '0.7.0,3.14159-63-dirty',
    :dot_version  => '0.7.0.rc1.63.dirty',
    :deb_version  => '0.7.0-0.1rc1.63dirtypuppetlabs1',
    :rpm_version  => '0.7.0',
    :rpm_release  => '0.1rc1.63dirty',
    :is_rc?       =>  true,

  },
  '0.7.0-63-ge391f55' => {
    :git_version  => %w{0.7.0 63},
    :dash_version => '0.7.0-63',
    :ips_version  => '0.7.0,3.14159-63',
    :dot_version  => '0.7.0.63',
    :deb_version  => '0.7.0.63-1puppetlabs1',
    :rpm_version  => '0.7.0.63',
    :rpm_release  => '1',
    :is_rc?       =>  false,

  },
  '0.7.0-63-ge391f55-dirty' => {
    :git_version  => %w{0.7.0 63 dirty},
    :dash_version => '0.7.0-63-dirty',
    :ips_version  => '0.7.0,3.14159-63-dirty',
    :dot_version  => '0.7.0.63.dirty',
    :deb_version  => '0.7.0.63.dirty-1puppetlabs1',
    :rpm_version  => '0.7.0.63.dirty',
    :rpm_release  => '1',
    :is_rc?       =>  false,
  },
}
describe Packaging::BuildInstance do

  before :each do
    @build = Packaging::BuildInstance.new
  end

  describe "#new" do
    Build_Params.each do |param|
      it "should have r/w accessors for #{param}" do
        @build.should respond_to(param)
        @build.should respond_to("#{param.to_s}=")
      end
    end
  end

  describe "#set_params_from_hash" do
    good_params = { :yum_host => 'foo', :pe_name => 'bar' }
    context "given a valid params hash #{good_params}" do
      it "should set instance variable values for each param" do
        good_params.each do |param, value|
          @build.should_receive(:instance_variable_set).with("@#{param}", value)
        end
        @build.set_params_from_hash(good_params)
      end
    end

    bad_params = { :foo => 'bar' }
    context "given an invalid params hash #{bad_params}" do
      bad_params.each do |param, value|
        it "should print a warning that param '#{param}' is not valid" do
          @build.should_receive(:warn).with(/No build data parameter found for '#{param}'/)
          @build.set_params_from_hash(bad_params)
        end

        it "should not try to set instance variable @:#{param}" do
          @build.should_not_receive(:instance_variable_set).with("@#{param}", value)
          @build.set_params_from_hash(bad_params)
        end
      end
    end

    mixed_params = { :sign_tar => TRUE, :baz => 'qux' }
    context "given a hash with both valid and invalid params" do
      it "should set the valid param" do
        @build.should_receive(:instance_variable_set).with("@sign_tar", TRUE)
        @build.set_params_from_hash(mixed_params)
      end

      it "should issue a warning that the invalid param is not valid" do
        @build.should_receive(:warn).with(/No build data parameter found for 'baz'/)
        @build.set_params_from_hash(mixed_params)
      end

      it "should not try to set instance variable @:baz" do
        @build.should_not_receive(:instance_variable_set).with("@baz", "qux")
        @build.set_params_from_hash(mixed_params)
      end
    end
  end

  describe "#params" do
    it "should return a hash containing keys for all build parameters" do
      expect( @build.params.keys - Build_Params ).to eq( [] )
    end
  end

  describe "#params_to_yaml" do
    it "should write a valid yaml file" do
      file = double('file')
      File.should_receive(:open).with(anything(), 'w').and_yield(file)
      file.should_receive(:puts).with(instance_of(String))
      YAML.should_receive(:load_file).with(file)
      expect { YAML.load_file(file) }.to_not raise_error
      @build.params_to_yaml
    end
  end

  TestVersions.keys.sort.each do |input|
    describe "Versioning based on #{input}" do

      results = TestVersions[input]
      results.keys.sort_by(&:to_s).each do |method|

        it "using #{method} #{input.inspect} becomes #{results[method].inspect}" do
          @build.release = "1"

          if method.to_s.include?("deb")
            @build.should_receive(:git_describe_internal).and_return(input)
            @build.packager = "puppetlabs"

          elsif method.to_s.include?("rpm")
            @build.should_receive(:git_describe_internal).and_return(input)

          else
            @build.stub(:uname_r) { "3.14159" }
            @build.stub(:is_git_repo) { true }
            @build.should_receive(:git_describe_internal).and_return(input)

          end

          @build.send(method).should == results[method]
        end
      end
    end
  end
end
