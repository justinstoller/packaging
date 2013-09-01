unless Kernel.respond_to? :require_relative
  def require_relative( lib )
    require File.expand_path( File.dirname(__FILE__) + '/' + lib )
  end
end

# Load packaging tasks

require_relative 'lib/packaging'
include Packaging::Utils

# These are ordered

PACKAGING_PATH = File.join(File.dirname(__FILE__), 'tasks')

@using_loader = true

[ '10_setupvars.rake',
  '20_setupextravars.rake',
  '30_metrics.rake',
  'apple.rake',
  'build.rake',
  'clean.rake',
  'deb.rake',
  'deb_repos.rake',
  'doc.rake',
  'fetch.rake',
  'gem.rake',
  'ips.rake',
  'jenkins.rake',
  'jenkins_dynamic.rake',
  'mock.rake',
  'pe_deb.rake',
  'pe_remote.rake',
  'pe_rpm.rake',
  'pe_ship.rake',
  'pe_sign.rake',
  'pe_tar.rake',
  'release.rake',
  'remote_build.rake',
  'retrieve.rake',
  'rpm.rake',
  'rpm_repos.rake',
  'ship.rake',
  'sign.rake',
  'tag.rake',
  'tar.rake',
  'template.rake',
  'update.rake',
  'vendor_gems.rake',
  'version.rake',
  'z_data_dump.rake'].each { |t| load File.join(PACKAGING_PATH, t)}

