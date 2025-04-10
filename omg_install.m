function omg_install(mode, options)
% omg_install - Runs first time setup for openMINDS-MATLAB-GUI (omg)
    
    arguments (Repeating)
        mode (1,1) string {mustBeMember(mode, ["force", "f", "update", "u", "savepath", "s"])};
    end

    arguments
        options.SavePathDef (1,1) logical = false 
    end

    mode = string(mode);

    if any(mode == "s") || any(mode == "savepath")
        options.SavePathDef = true;
        mode = setdiff(mode, ["s", "savepath"], 'stable');
    end

    % Assumes omg_install.m is located in the root folder of the repository 
    omuiRootPath = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(omuiRootPath, 'code')))
    addpath(genpath(fullfile(omuiRootPath, 'tools')))
    
    omuitools.installMatBox("commit")
    matbox.installRequirements(omuiRootPath, mode{:})

    run( fullfile(om.internal.rootpath, 'startup.m') )
    %matbox.runStartupFile(omgRootPath); % Future

    if options.SavePathDef
        savepath()
    end
end
