function packageToolbox(releaseType, versionString)
    arguments
        releaseType {mustBeTextScalar,mustBeMember(releaseType,["build","major","minor","patch","specific"])} = "build"
        versionString {mustBeTextScalar} = "";
    end

    if ~(exist('matbox', 'dir') == 7)
        omuitools.installMatBox("commit")
    end
    projectRootDirectory = omuitools.projectdir();

    toolboxPathFolders = [...
        fullfile(projectRootDirectory, "code"), ...
        fullfile(projectRootDirectory, "code", "apps") ...
    ];

    matbox.tasks.packageToolbox(projectRootDirectory, releaseType, versionString, ...
        "ToolboxShortName", "openMINDS_MATLAB_UI", ...
        "PathFolders", toolboxPathFolders)
end
