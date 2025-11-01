function disableAxesToolbar(hAxes)
% disableAxesToolbar - Disable axes toolbox in recent MATLAB releases    
    matlabVersion = version('-release');
    doDisableToolbar = str2double(matlabVersion(1:4))>2018 || ...
                               strcmp(matlabVersion, '2018b');

    if doDisableToolbar
        hAxes.Toolbar = [];
        disableDefaultInteractivity(hAxes)
    end
end
