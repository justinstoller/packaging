
namespace :package do
  desc "Create srpm from this git repository (unsigned)"
  task :srpm => :tar do
    build_rpm("-bs")
  end

  desc "Create .rpm from this git repository (unsigned)"
  task :rpm => :tar do
    build_rpm("-ba")
  end
end

