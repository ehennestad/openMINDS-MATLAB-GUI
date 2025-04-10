function writeCommitHash(repositoryFolderPath, repositoryName, organizationName, branchName)
    commitId = om.internal.setup.github.getCurrentCommitID(repositoryName, ...
        'Organization', organizationName, "BranchName", branchName);
    filePath = fullfile(repositoryFolderPath, '.commit_hash');
    om.internal.fileio.filewrite(filePath, commitId)
end
