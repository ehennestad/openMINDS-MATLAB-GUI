function addDependenciesToPath()

    warnState = warning('off', 'MATLAB:javaclasspath:jarAlreadySpecified');
    warnCleanupObj = onCleanup(@() warning(warnState));

    reqs = om.internal.setup.getRequirements();

    for i = 1:numel(reqs)
        switch reqs(i).Type
            case 'GitHub'
                % Todo.
                %[repoUrl, branchName] = parseGitHubUrl(reqs(i).URI);
                %om.internal.setup.installGithubRepository( repoUrl, branchName )
            
            case 'FileExchange'
                [packageUuid, version] = om.internal.setup.fex.parseFileExchangeURI( reqs(i).URI );
                [isInstalled, version] = om.internal.setup.fex.isToolboxInstalled(packageUuid, version);
                if isInstalled
                    matlab.addons.enableAddon(packageUuid, version)
                end
            case 'Unknown'
                continue
        end
    end
    
    % Add all addons in the package's addon folder to path
    addonLocation = om.internal.constant.AddonTargetFolder();

    addonListing = dir(addonLocation);

    for i = 1:numel(addonListing)
        if startsWith(addonListing(i).name, '.')
            continue
        end
        if ~addonListing(i).isdir
            continue
        end

        folderPath = fullfile(addonListing(i).folder, addonListing(i).name);
        startupFile = om.internal.setup.findStartupFile(folderPath);
        
        if ~isempty(startupFile)
            run( startupFile )
        else
            addpath(genpath(folderPath))
        end
    end
end
