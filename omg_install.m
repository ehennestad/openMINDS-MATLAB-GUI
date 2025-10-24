function omg_install(flags, options)
% omg_install - Runs first time setup for openMINDS-MATLAB-GUI (omg)
    
    arguments (Repeating)
        flags (1,1) string {mustBeMember(flags, ["force", "f", "update", "u", "savepath", "s"])};
    end

    arguments
        options.SavePathDef (1,1) logical = false 
    end

    flags = string(flags);

    if any(flags == "s") || any(flags == "savepath")
        options.SavePathDef = true;
        flags = setdiff(flags, ["s", "savepath"], 'stable');
    end

    % Assumes omg_install.m is located in the root folder of the repository 
    omuiRootPath = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(omuiRootPath, 'code')))
    addpath(genpath(fullfile(omuiRootPath, 'tools')))
    if exist('+matbox/installRequirements', 'file') ~= 2
        omuitools.installMatBox("commit")
    end
    
    % Turn off warning that might show if the WidgetsToolbox dependency is
    % already installed
    warnState = warning('off', 'MATLAB:javaclasspath:jarAlreadySpecified');
    warnCleanupObj = onCleanup(@() warning(warnState));

    matbox.installRequirements(omuiRootPath, flags{:}, ...
        "SaveSearchPath", options.SavePathDef)

    run( fullfile(om.internal.rootpath, 'startup.m') )
    %matbox.runStartupFile(omgRootPath); % Future
end
