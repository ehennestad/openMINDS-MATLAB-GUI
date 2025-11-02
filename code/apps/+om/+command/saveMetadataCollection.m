function saveMetadataCollection(metadataCollection, filepath)
% saveMetadataCollection - Export a metadata collection to a MAT file
%
%   saveMetadataCollection(metadataCollection, filepath) saves the given
%   metadata collection object to the specified filepath as a MAT file.
%
%   saveMetadataCollection(metadataCollection) saves the metadata 
%   collection to the default location using saveMetadataCollection.
%
%   Inputs:
%       metadataCollection - A metadata collection object (om.ui.UICollection)
%       filepath - (optional) Full path to the MAT file where the 
%                  collection should be saved. If not provided, falls back
%                  to saveMetadataCollection.
%
%   Example:
%       % Export to a specific file
%       saveMetadataCollection(myCollection, 'path/to/my_collection.mat')
%
%       % Export to default location
%       saveMetadataCollection(myCollection)

    arguments
        metadataCollection
        filepath char = ''
    end
    
    % If no filepath is provided, use the default location
    if isempty(filepath)
        % Use the default save folder from preferences or userpath
        saveFolder = fullfile(userpath, 'openMINDS-MATLAB-UI', 'userdata');
        if ~isfolder(saveFolder)
            mkdir(saveFolder);
        end
        filepath = fullfile(saveFolder, 'metadata_collection.mat');
    end
    
    % Validate that the metadata collection is provided
    if isempty(metadataCollection)
        error('openMINDS_GUIDE:saveMetadataCollection:EmptyCollection', ...
            'Metadata collection cannot be empty.');
    end
    
    % Ensure the directory exists
    [folderPath, ~, ~] = fileparts(filepath);
    if ~isempty(folderPath) && ~isfolder(folderPath)
        mkdir(folderPath);
    end
    
    % Save the metadata collection to the specified file
    MetadataCollection = metadataCollection;
    save(filepath, 'MetadataCollection');
    
    fprintf('Metadata collection exported to %s\n', filepath);
end
