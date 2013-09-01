# Perform a build exclusively from a build params file. Requires that the build
# params file include a setting for task, which is an array of the arguments
# given to rake originally, including, first, the task name. The params file is
# always loaded when passed, so these variables are accessible immediately.
namespace :pl do
  desc "Build from a build params file"
  task :build_from_params do
    check_var('PARAMS_FILE', ENV['PARAMS_FILE'])
    git_co(@build.ref)
    Rake::Task[@build.task[:task]].invoke(@build.task[:args])
  end
end
