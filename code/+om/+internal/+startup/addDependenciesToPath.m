function addDependenciesToPath()

    warnState = warning('off', 'MATLAB:javaclasspath:jarAlreadySpecified');
    warnCleanupObj = onCleanup(@() warning(warnState));
    
    reqs = om.internal.startup.getRequirements();

    % Add all addons in the package's addon folder to path
    addonLocation = om.internal.constant.AddonTargetFolder();

    for i = 1:numel(reqs)
        switch reqs(i).Type
            case 'GitHub'
                [~, repositoryName, branchName] = parseRepositoryURL(reqs(i).URI);
                installLocation = fullfile(addonLocation, sprintf('%s-%s', repositoryName, branchName));
                if isfolder(installLocation)
                    addGithubDependencyToPath(installLocation)
                end

            case 'FileExchange'
                [packageUuid, version] = om.internal.startup.fex.parseFileExchangeURI( reqs(i).URI );
                try
                    [isInstalled, version] = om.internal.startup.fex.isToolboxInstalled(packageUuid, version);
                catch ME
                    warning(ME.identifier, 'Failed to check if FEX package "%s" is installed with message:\n%s\n', reqs(i).URI, ME.message)
                    isInstalled = false;
                end
                if isInstalled
                    matlab.addons.enableAddon(packageUuid, version)
                end
            case 'Unknown'
                continue
        end
    end
end

function [organization, repositoryName, branchName] = parseRepositoryURL(repoUrl)
% parseRepositoryURL - Extract organization, repository name and branch name
    
    arguments
        repoUrl (1,1) matlab.net.URI
    end
    
    if repoUrl.Host ~= "github.com"
        error("SETUPTOOLS:GITHUB:InvalidRepositoryURL", ...
            "Please make sure the repository URL's host name is 'github.com'")
    end
    
    pathNames = repoUrl.Path;
    pathNames( cellfun('isempty', pathNames) ) = [];

    organization = pathNames(1);
    repositoryName = pathNames(2);

    if contains(repositoryName, '@')
        splitName = split(repositoryName, '@');
        repositoryName = splitName(1);
        branchName = splitName(2);
    else
        branchName = "main";
    end

    if nargout < 3
        clear branchName
    end
end

function addGithubDependencyToPath(folderPath)
    startupFile = om.internal.startup.findStartupFile(folderPath);
    
    if ~isempty(startupFile)
        run( startupFile )
    else
        addpath(genpath(folderPath))
    end
end

