function filepath = saveMetadataCollectionAs(metadataCollection, defaultFilename)
% saveMetadataCollectionAs - Save a metadata collection with user-selected filepath
%
%   filepath = saveMetadataCollectionAs(metadataCollection) opens a file
%   dialog allowing the user to select where to save the metadata collection.
%   Returns the filepath where the collection was saved, or empty if the
%   user cancelled.
%
%   filepath = saveMetadataCollectionAs(metadataCollection, defaultFilename)
%   opens the file dialog with the specified default filename.
%
%   Inputs:
%       metadataCollection - A metadata collection object (om.ui.UICollection)
%       defaultFilename - (optional) Default filename to suggest in the dialog
%                         Default: 'metadata_collection.mat'
%
%   Outputs:
%       filepath - Full path to the saved file, or empty if cancelled
%
%   Example:
%       % Save with default filename
%       filepath = saveMetadataCollectionAs(myCollection)
%
%       % Save with custom default filename
%       filepath = saveMetadataCollectionAs(myCollection, 'my_project.mat')

    arguments
        metadataCollection
        defaultFilename char = 'metadata_collection.mat'
    end
    
    % Validate that the metadata collection is provided
    if isempty(metadataCollection)
        error('openMINDS_GUIDE:saveMetadataCollectionAs:EmptyCollection', ...
            'Metadata collection cannot be empty.');
    end
    
    % Get default location from preferences or userpath
    defaultFolder = fullfile(userpath, 'openMINDS-MATLAB-UI', 'userdata');
    if ~isfolder(defaultFolder)
        defaultFolder = userpath;
    end
    

    % Open file dialog for user to select save location
    ff = om.external.fex.fixfocus.fixfocus();
    [filename, pathname] = uiputfile(...
        {'*.mat', 'MAT-files (*.mat)'; ...
         '*.*', 'All Files (*.*)'}, ...
        'Save Metadata Collection As', ...
        fullfile(defaultFolder, defaultFilename));
    delete(ff)

    % Check if user cancelled
    if isequal(filename, 0) || isequal(pathname, 0)
        filepath = '';
        fprintf('Save operation cancelled.\n');
        return
    end
    
    % Construct full filepath
    filepath = fullfile(pathname, filename);
    
    % Ensure the directory exists
    if ~isfolder(pathname)
        mkdir(pathname);
    end
    
    % Save the metadata collection to the selected file
    MetadataCollection = metadataCollection;
    save(filepath, 'MetadataCollection');
    
    fprintf('Metadata collection saved to %s\n', filepath);
end
