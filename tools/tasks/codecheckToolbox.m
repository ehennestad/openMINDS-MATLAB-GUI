function issues = codecheckToolbox()
% codecheckToolbox - Identify code issues for openMINDS_MATLAB toolbox

    omuitools.installMatBox("commit")
    projectRootDirectory = omuitools.projectdir();
    
    toolboxFileInfo = dir(fullfile(projectRootDirectory, "**", "*.m"));
    filesToCheck = fullfile(string({toolboxFileInfo.folder}'),string({toolboxFileInfo.name}'));

    skip = false(size(filesToCheck));
    skip = skip | contains(filesToCheck, 'code/external') | contains(filesToCheck, 'code/+om/+external');

    filesToCheck(skip) = [];

    issues = matbox.tasks.codecheckToolbox(projectRootDirectory, ...
        "CreateBadge", true, "FilesToCheck", filesToCheck);
end
