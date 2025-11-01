function [metadataCollection, filepath] = openMetadataCollection(filepath)
% openMetadataCollection - Open a metadata collection from a file
%
%   [metadataCollection, filepath] = openMetadataCollection() opens a file
%   dialog allowing the user to select a metadata collection file to open.
%   Returns the loaded collection and the filepath.
%
%   [metadataCollection, filepath] = openMetadataCollection(filepath)
%   opens the collection from the specified filepath.
%
%   Inputs:
%       filepath - (optional) Full path to the metadata collection file
%
%   Outputs:
%       metadataCollection - The loaded metadata collection object
%       filepath - Full path to the opened file (empty if cancelled)
%
%   Example:
%       % Open with file dialog
%       [collection, path] = openMetadataCollection()
%
%       % Open specific file
%       collection = openMetadataCollection('/path/to/collection.mat')

    arguments
        filepath char = ''
    end
    
    % If no filepath provided, show file dialog
    if isempty(filepath)
        % Get default location from recent files or userpath
        defaultFolder = om.internal.RecentFileManager.getDefaultOpenFolder('collections');
        
        % Open file dialog
        ff = om.external.fex.fixfocus.fixfocus();
        [filename, pathname] = uigetfile(...
            {'*.mat', 'MAT-files (*.mat)'; ...
             '*.*', 'All Files (*.*)'}, ...
            'Open Metadata Collection', ...
            defaultFolder);
        delete(ff)
        
        % Check if user cancelled
        if isequal(filename, 0) || isequal(pathname, 0)
            metadataCollection = [];
            filepath = '';
            return
        end
        
        filepath = fullfile(pathname, filename);
    end
    
    % Validate that the file exists
    if ~isfile(filepath)
        error('om:openMetadataCollection:FileNotFound', ...
            'Metadata collection file not found: %s', filepath);
    end
    
    % Load the metadata collection
    try
        S = load(filepath, 'MetadataCollection');
        
        if ~isfield(S, 'MetadataCollection')
            error('om:openMetadataCollection:InvalidFile', ...
                'File does not contain a MetadataCollection variable: %s', filepath);
        end
        
        metadataCollection = S.MetadataCollection;
        
        fprintf('Metadata collection loaded from: %s\n', filepath);
        
    catch ME
        error('om:openMetadataCollection:LoadError', ...
            'Error loading metadata collection from %s: %s', filepath, ME.message);
    end
    
    % Clear output if not requested
    if nargout == 0
        clear metadataCollection filepath
    end
end
