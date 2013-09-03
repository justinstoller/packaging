# The pl:load_extras tasks is intended to load variables
# from the extra yaml file downloaded by the pl:fetch task.
# The goal is to be able to augment/override settings in the
# source project's build_data.yaml and project_data.yaml with
# Puppet Labs-specific data, rather than having to clutter the
# generic tasks with data not generally useful outside the
# PL Release team
namespace :pl do
  task :load_extras, :tempdir do |t, args|
    unless ENV['PARAMS_FILE'] && ENV['PARAMS_FILE'] != ''
      tempdir = args.tempdir
      raise "pl:load_extras requires a directory containing extras data" if tempdir.nil?

      @build.load_extra_params_from( tempdir )
    end

    # Warn that the user asked to do something and we're not going to....
  end
end

##
# Starting with puppetdb, we'll maintain two separate build-data files, one for
# PE and the other for FOSS. This is the start to maintaining both PE and FOSS
# packaging in one source repo. As is done in 10_setupvars.rake, the @name
# variable is set to the value of @project, for backwards compatibility.
#
unless @build.pe_name.nil?
  @build.project = @build.pe_name
  @build.name    = @build.project
end
