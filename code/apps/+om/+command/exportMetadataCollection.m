function exportMetadataCollection(metadataCollection, filepath, options)
% exportMetadataCollection - Export a metadata collection to JSON-LD format
%
%   exportMetadataCollection(metadataCollection) opens a dialog
%   allowing the user to configure export options and select where to save
%   the JSON-LD file(s).
%
%   exportMetadataCollection(metadataCollection, filepath) exports
%   the collection to the specified filepath using default options (single
%   file export).
%
%   Inputs:
%       metadataCollection - A metadata collection object (om.ui.UICollection
%                            or openminds.Collection)
%       filepath - (optional) Path where the JSON-LD should be saved.
%                  If a folder path, exports to multiple files.
%                  If a file path, exports to a single file.
%
%   Example:
%       % Interactive export with options dialog
%       exportMetadataCollection(myCollection)
%
%       % Direct export to single file
%       exportMetadataCollection(myCollection, 'path/to/collection.jsonld')
%
%       % Direct export to folder (multiple files)
%       exportMetadataCollection(myCollection, 'path/to/folder/')

    arguments
        metadataCollection
        filepath char = ''
        options.ReferenceWindow
    end
    
    % Validate that the metadata collection is provided
    if isempty(metadataCollection)
        error('openMINDS:exportMetadataCollection:EmptyCollection', ...
            'Metadata collection cannot be empty.');
    end
    
    % % Convert om.ui.UICollection to openminds.Collection if needed
    % if isa(metadataCollection, 'om.ui.UICollection')
    %     openmindsMDCollection = metadataCollection.toCollection();
    % elseif isa(metadataCollection, 'openminds.Collection')
    %     openmindsMDCollection = metadataCollection;
    % else
    %     error('openMINDS:exportMetadataCollection:InvalidType', ...
    %         'Metadata collection must be of type om.ui.UICollection or openminds.Collection.');
    % end

    openmindsMDCollection=metadataCollection;
    
    % If filepath is provided, export directly with default options
    if ~isempty(filepath)
        exportWithDefaultOptions(openmindsMDCollection, filepath);
        return
    end
    
    % Otherwise, show options dialog
    exportWithOptionsDialog(openmindsMDCollection);
end

function exportWithDefaultOptions(collection, filepath)
% Export with default options (no dialog)
    
    % Determine if exporting to single file or folder based on filepath
    if isfolder(filepath)
        % Export to folder (multiple files)
        collection.save(filepath);
        fprintf('Metadata collection exported to folder: %s\n', filepath);
    else
        % Export to single file
        collection.save(filepath);
        fprintf('Metadata collection exported to: %s\n', filepath);
    end
end

function exportWithOptionsDialog(collection)
% Show options dialog and export based on user choices
    
    % Create default export options structure
    exportOptions = struct();
    exportOptions.ExportFormat = categorical({'Single File'}, {'Single File', 'Multiple Files'});
    exportOptions.OutputPath = fullfile(userpath, 'openMINDS-MATLAB-UI', 'exports');
    exportOptions.Filename = 'metadata_collection.jsonld';
    exportOptions.UpdateLinks = true;
    
    % Open the struct editor dialog
    hEditor = structeditor.StructEditorApp(exportOptions, ...
        "Title", 'Export Metadata Collection to JSON-LD', ...
        'LoadingHtmlSource', om.internal.getSpinnerSource());
    
    hEditor.OkButtonText = 'Export';
    hEditor.alwaysOnTop()
    uiwait(hEditor, true);
    
    % Check if user cancelled
    if hEditor.FinishState ~= "Finished"
        hEditor.reset();
        delete(hEditor);
        error('Export operation cancelled.');
    end
    
    % Get the edited options
    exportOptions = hEditor.Data;
    hEditor.hide();
    hEditor.reset();
    
    % Ensure output directory exists
    if ~isfolder(exportOptions.OutputPath)
        mkdir(exportOptions.OutputPath);
    end
    
    % Update links if requested
    if exportOptions.UpdateLinks
        collection.updateLinks();
    end
    
    % Perform the export based on selected format
    if strcmp(string(exportOptions.ExportFormat), 'Single File')
        % Export to single file
        fullPath = fullfile(exportOptions.OutputPath, exportOptions.Filename);
        
        % Ensure .jsonld extension
        [~, ~, ext] = fileparts(fullPath);
        if isempty(ext)
            fullPath = [fullPath, '.jsonld'];
        end
        
        collection.save(fullPath);
        fprintf('Metadata collection exported to: %s\n', fullPath);
        
    else
        % Export to multiple files in folder
        outputFolder = exportOptions.OutputPath;
        
        % Create subfolder with timestamp to avoid overwriting
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        outputFolder = fullfile(outputFolder, ['export_', timestamp]);
        
        if ~isfolder(outputFolder)
            mkdir(outputFolder);
        end
        
        collection.save(outputFolder);
        fprintf('Metadata collection exported to folder: %s\n', outputFolder);
    end
end
