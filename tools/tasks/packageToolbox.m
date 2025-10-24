function [newVersion, mltbxPath] = packageToolbox(releaseType, versionString, varargin)
    arguments
        releaseType {mustBeTextScalar,mustBeMember(releaseType,["build","major","minor","patch","specific"])} = "build"
        versionString {mustBeTextScalar} = "";
    end
    arguments (Repeating)
        varargin
    end

    projectRootDirectory = omuitools.projectdir();

    toolboxPathFolders = [...
        fullfile(projectRootDirectory, "code"), ...
        fullfile(projectRootDirectory, "code", "apps") ...
    ];

    [newVersion, mltbxPath] = matbox.tasks.packageToolbox(projectRootDirectory, releaseType, versionString, ...
        varargin{:}, ...
        "ToolboxShortName", "openMINDS_MATLAB_UI", ...
        "PathFolders", toolboxPathFolders);
end
