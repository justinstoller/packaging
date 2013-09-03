
namespace :pl do
  desc "Use default mock to make a final rpm, keyed to PL infrastructure, pass MOCK to specify config"
  task :mock => "package:tar" do
    # If default mock isn't specified, just take the first one in the @build.final_mocks list
    @build.default_mock ||= @build.final_mocks.split(' ')[0]
    build_rpm_with_mock(@build.default_mock)
    post_metrics if @build.benchmark
  end

  desc "Use specified mocks to make rpms, keyed to PL infrastructure, pass MOCK to specifiy config"
  task :mock_all => "package:tar" do
    build_rpm_with_mock(@build.final_mocks)
    post_metrics if @build.benchmark
  end
end
