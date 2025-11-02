classdef RecentFileManager
    % RecentFileManager - Manages lists of recently opened files by category
    %
    %   This class provides static methods to track, retrieve, and manage
    %   recently opened files. Files are organized by category (e.g., 
    %   'collections', 'exports') and persisted to disk in JSON format 
    %   within MATLAB's prefdir.
    %
    %   Methods (Static):
    %       addRecentFile(category, filepath, displayName)  - Add file to recent list
    %       getRecentFiles(category)                        - Get array of recent file info
    %       removeRecentFile(category, filepath)            - Remove a specific file
    %       clearRecentFiles(category)                      - Clear the entire recent list
    %       cleanupNonExistentFiles(category)               - Remove non-existent files
    %       getDefaultOpenFolder(category)                  - Get default folder for category
    %
    %   Example:
    %       % Add a file to recent list
    %       om.internal.RecentFileManager.addRecentFile('collections', '/path/to/file.mat')
    %       
    %       % Get recent files
    %       recentList = om.internal.RecentFileManager.getRecentFiles('collections')
    %       
    %       % Clear recent files
    %       om.internal.RecentFileManager.clearRecentFiles('collections')
    
    properties (Constant, Access = private)
        MAX_RECENT_ITEMS = 10
        PREFS_FOLDER = fullfile(prefdir, 'openMINDS-MATLAB-GUI')
    end
    
    methods (Static)
        
        function addRecentFile(category, filepath, displayName)
            % addRecentFile - Add a file to the recent list for a category
            %
            %   addRecentFile(category, filepath) adds the specified file to the
            %   recent files list for the given category. If the file already 
            %   exists in the list, it is moved to the top. The list is limited 
            %   to MAX_RECENT_ITEMS most recent files per category.
            %
            %   addRecentFile(category, filepath, displayName) also stores
            %   a custom display name for the file.
            %
            %   Inputs:
            %       category - Category name (e.g., 'collections', 'exports')
            %       filepath - Full path to the file
            %       displayName - (optional) Custom display name for the file
            
            arguments
                category char
                filepath char
                displayName char = ''
            end
            
            % Validate that file exists
            if ~isfile(filepath)
                warning('om:RecentFiles:FileNotFound', ...
                    'Cannot add non-existent file to recent list: %s', filepath);
                return
            end
            
            % Convert to absolute path
            filepath = om.internal.RecentFileManager.getAbsolutePath(filepath);
            
            % Load existing recent list for this category
            recentList = om.internal.RecentFileManager.loadRecentList(category);
            
            % Check if this file is already in the list
            existingIdx = [];
            for i = 1:numel(recentList)
                if strcmp(recentList(i).filepath, filepath)
                    existingIdx = i;
                    break;
                end
            end
            
            % Create new entry
            newEntry = struct();
            newEntry.filepath = filepath;
            newEntry.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            
            if ~isempty(displayName)
                newEntry.name = displayName;
            elseif ~isempty(existingIdx) && isfield(recentList(existingIdx), 'name')
                % Preserve existing name if updating
                newEntry.name = recentList(existingIdx).name;
            else
                % Use filename as default name
                [~, fname, fext] = fileparts(filepath);
                newEntry.name = [fname, fext];
            end
            
            % Remove existing entry if present
            if ~isempty(existingIdx)
                recentList(existingIdx) = [];
            end
            
            % Add new entry at the beginning
            if isempty(recentList)
                recentList = newEntry;
            else
                recentList = [newEntry, recentList];
            end
            
            % Limit to MAX_RECENT_ITEMS
            if numel(recentList) > om.internal.RecentFileManager.MAX_RECENT_ITEMS
                recentList = recentList(1:om.internal.RecentFileManager.MAX_RECENT_ITEMS);
            end
            
            % Save updated list
            om.internal.RecentFileManager.saveRecentList(category, recentList);
        end
        
        function recentList = getRecentFiles(category)
            % getRecentFiles - Get array of recent file info for a category
            %
            %   recentList = getRecentFiles(category) returns a struct array
            %   containing information about recently opened files in the
            %   specified category.
            %
            %   Input:
            %       category - Category name (e.g., 'collections', 'exports')
            %
            %   Output:
            %       recentList - Struct array with fields:
            %                    .filepath   - Full path to file
            %                    .name       - Display name
            %                    .timestamp  - Last opened timestamp
            %                    .exists     - Boolean indicating if file exists
            
            arguments
                category char
            end
            
            % Load the list
            recentList = om.internal.RecentFileManager.loadRecentList(category);
            
            % Check which files still exist
            for i = 1:numel(recentList)
                recentList(i).exists = isfile(recentList(i).filepath);
            end
        end
        
        function removeRecentFile(category, filepath)
            % removeRecentFile - Remove a specific file from the recent list
            %
            %   removeRecentFile(category, filepath) removes the specified file
            %   from the recent files list for the given category.
            %
            %   Inputs:
            %       category - Category name
            %       filepath - Full path to the file to remove
            
            arguments
                category char
                filepath char
            end
            
            % Convert to absolute path
            filepath = om.internal.RecentFileManager.getAbsolutePath(filepath);
            
            % Load existing list
            recentList = om.internal.RecentFileManager.loadRecentList(category);
            
            % Find and remove the entry
            keepIdx = true(1, numel(recentList));
            for i = 1:numel(recentList)
                if strcmp(recentList(i).filepath, filepath)
                    keepIdx(i) = false;
                end
            end
            
            recentList = recentList(keepIdx);
            
            % Save updated list
            om.internal.RecentFileManager.saveRecentList(category, recentList);
        end
        
        function clearRecentFiles(category)
            % clearRecentFiles - Clear the entire recent files list for a category
            %
            %   clearRecentFiles(category) removes all entries from the recent
            %   files list for the specified category.
            %
            %   Input:
            %       category - Category name
            
            arguments
                category char
            end
            
            % Save empty list
            om.internal.RecentFileManager.saveRecentList(category, []);
        end
        
        function cleanupNonExistentFiles(category)
            % cleanupNonExistentFiles - Remove non-existent files from the list
            %
            %   cleanupNonExistentFiles(category) removes all entries that 
            %   point to files that no longer exist on disk for the specified
            %   category.
            %
            %   Input:
            %       category - Category name
            
            arguments
                category char
            end
            
            recentList = om.internal.RecentFileManager.loadRecentList(category);
            
            % Filter to keep only existing files
            keepIdx = false(1, numel(recentList));
            for i = 1:numel(recentList)
                keepIdx(i) = isfile(recentList(i).filepath);
            end
            
            recentList = recentList(keepIdx);
            
            % Save cleaned list
            om.internal.RecentFileManager.saveRecentList(category, recentList);
        end
        
        function defaultFolder = getDefaultOpenFolder(category)
            % getDefaultOpenFolder - Get default folder for file open dialog
            %
            %   defaultFolder = getDefaultOpenFolder(category) returns the folder
            %   of the most recent file in the category, or a default path if
            %   no recent files exist.
            %
            %   Input:
            %       category - Category name
            
            arguments
                category char
            end
            
            recentList = om.internal.RecentFileManager.getRecentFiles(category);
            
            if ~isempty(recentList) && isfield(recentList, 'filepath')
                % Use folder of most recent file
                mostRecentPath = recentList(1).filepath;
                if isfile(mostRecentPath)
                    defaultFolder = fileparts(mostRecentPath);
                    return
                end
            end
            
            % Fall back to default location
            defaultFolder = fullfile(userpath, 'openMINDS-MATLAB-UI', 'userdata');
            if ~isfolder(defaultFolder)
                defaultFolder = userpath;
            end
        end
    end
    
    methods (Static, Access = private)
        
        function prefsFile = getPrefsFile(category)
            % getPrefsFile - Get the preferences file path for a category
            %
            %   prefsFile = getPrefsFile(category) returns the full path
            %   to the JSON file for the specified category.
            
            filename = sprintf('recent_%s.json', category);
            prefsFile = fullfile(om.internal.RecentFileManager.PREFS_FOLDER, filename);
        end
        
        function recentList = loadRecentList(category)
            % loadRecentList - Load recent files list from disk for a category
            %
            %   recentList = loadRecentList(category) loads and returns the recent
            %   files list for the specified category from the preferences file. 
            %   Returns empty struct array if file doesn't exist.
            
            prefsFile = om.internal.RecentFileManager.getPrefsFile(category);
            
            if isfile(prefsFile)
                try
                    % Read JSON file
                    jsonText = fileread(prefsFile);
                    S = jsondecode(jsonText);
                    
                    if isfield(S, 'RecentFiles') && ~isempty(S.RecentFiles)
                        recentList = S.RecentFiles;
                        
                        % Ensure it's a struct array, not a scalar struct with cell arrays
                        if ~isstruct(recentList)
                            recentList = struct([]);
                        end
                    else
                        recentList = struct([]);
                    end
                catch ME
                    warning('om:RecentFiles:LoadError', ...
                        'Error loading recent files for category "%s": %s', category, ME.message);
                    recentList = struct([]);
                end
            else
                recentList = struct([]);
            end
        end
        
        function saveRecentList(category, recentList)
            % saveRecentList - Save recent files list to disk for a category
            %
            %   saveRecentList(category, recentList) saves the provided recent
            %   files list for the specified category to the preferences file 
            %   in JSON format.
            
            prefsFolder = om.internal.RecentFileManager.PREFS_FOLDER;
            prefsFile = om.internal.RecentFileManager.getPrefsFile(category);
            
            % Create preferences folder if it doesn't exist
            if ~isfolder(prefsFolder)
                mkdir(prefsFolder);
            end
            
            % Create structure for JSON encoding
            S = struct();
            if isempty(recentList)
                S.RecentFiles = [];
            else
                S.RecentFiles = recentList;
            end
            
            % Save to JSON file
            try
                jsonText = jsonencode(S, 'PrettyPrint', true);
                fid = fopen(prefsFile, 'w');
                if fid == -1
                    error('Could not open file for writing: %s', prefsFile);
                end
                fwrite(fid, jsonText, 'char');
                fclose(fid);
            catch ME
                warning('om:RecentFiles:SaveError', ...
                    'Error saving recent files for category "%s": %s', category, ME.message);
            end
        end
        
        function absolutePath = getAbsolutePath(filepath)
            % getAbsolutePath - Convert relative path to absolute path
            %
            %   absolutePath = getAbsolutePath(filepath) converts the
            %   provided filepath to an absolute path.
            
            if ~isempty(filepath)
                % Get file info to resolve full path
                fileInfo = dir(filepath);
                if ~isempty(fileInfo)
                    absolutePath = fullfile(fileInfo.folder, fileInfo.name);
                else
                    % File doesn't exist, but try to resolve anyway
                    [filepath_abs, ~, ~] = fileparts(filepath);
                    if isempty(filepath_abs)
                        absolutePath = fullfile(pwd, filepath);
                    else
                        absolutePath = filepath;
                    end
                end
            else
                absolutePath = '';
            end
        end
    end
end
