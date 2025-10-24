function filePath = getSpinnerSource(spinnerName)
    arguments
        spinnerName (1,1) string = "pulsing_continous"
    end
    folderPath = fullfile( om.internal.rootpath(), 'apps', 'resources', 'spinners');

    fileName = spinnerName + ".html";
    filePath = fullfile(folderPath, fileName);
end
