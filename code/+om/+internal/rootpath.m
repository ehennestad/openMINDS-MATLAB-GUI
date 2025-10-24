function rootPath = rootpath()
% rootpath - Return rootpath for the openMINDS code folder.

    import om.internal.utility.pathparts

    FILE_DEPTH = 3; % Relative to root

    thisPathSplit = pathparts( mfilename("fullpath") );
    rootPath = strjoin(thisPathSplit(1:end-FILE_DEPTH), filesep);
end
