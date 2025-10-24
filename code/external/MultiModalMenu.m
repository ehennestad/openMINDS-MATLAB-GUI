classdef MultiModalMenu < handle
%MultiModalMenu Create a menu where each item can have multiple modes
%
%   These functions are then saved in a package hierarchy, and this
%   hierarchy will be used here to create a uimenu using the same 
%   hierarchy.
%
%   Each menu item corresponding to a session method will be configured to
%   trigger the event MethodSelected when the menu item is selected. The
%   eventdata for this event contains two properties:
%       'TaskAttributes' : A struct with attributes for a session task
%       'Mode' : The mode for which the method should be run
%
%   The mode is one of the following: 
%       - 'Default'
%       - 'Preview' 
%       - 'TaskQueue'
%       - 'Edit' 
%
%   The mode is determined by the value of the Mode property at the time
%   when the event is triggered. The Mode property has no functionality in
%   this class, but can be used by external code for configuring different
%   ways of running methods (see nansen.App for example...)


%   Notes on implementation: 
%       This class is implemented to create the menu structure from a
%       package folder hierarchy. Maybe that functionality should be
%       separated out into its own class.


% Dependencies:
%       FileExchange : findjobj

    % TODO
    %   [ ] Add (and save) menu shortcuts (accelerators)
    %   [ ] Can the menus be created more efficiently, with regards to
    %       getting task attributes
    %   [ ] Add a mode called update (for updating specific menu item)
    %   [ ] Create from folder.
    %   [ ] Add attributes. Maybe some modes are not valid for all items in
    %       the menu
    %   [ ] Consider if tree data structure is useful:
    %       https://www.mathworks.com/matlabcentral/fileexchange/35623-tree-data-structure-as-a-matlab-class?s_tid=srchtitle

    properties (Abstract, Constant, Hidden) % Todo: Abstract
        ValidModes % = {'Single', 'Multiple', 'Help'}                         % Available modes, use categoricals?
        DefaultMode
        MenuOrder % = {'+data', '+process', '+analyze', '+plot'}              % Todo: preference?
    end

    properties (Abstract) % Todo: Inherit from a superclass (folder to menu?)
        DirectoryIgnore
    end

    properties (Abstract, Constant, Hidden)
        KEY_TO_MODE_MAP
    end
    
    properties
        Mode char % The default mode Todo: first on list? or abstract
    end

    properties
        MenuSelectedFcn % Function handle to run when menu is selected.
    end

    properties (SetAccess = immutable)
        UseModuleAsRoot = false;
    end
    
    properties (SetAccess = private)
        ParentApp = [] % todo: should be specific app instance. % Handle of the app for the session task menu
        Figure         % Handle to figure which the menu belongs to
    end

    properties (Access = private)
        KeyPressListener event.listener
        KeyReleasedListener event.listener
    end
    
    properties (Access = private)
        hMenuDirs matlab.ui.container.Menu
        hMenuItems matlab.ui.container.Menu
        FunctionalItems struct = struct
    end

    properties (Access = private)
        PackageModules cell
        DefaultMethodsPath cell % Pathstr for a package folder containing items for the menus.
    end

    properties (Access = private)
        IsModeLocked = false % todo: timer to unlock
    end

    events
        MethodSelected % todo: remove
    end


    methods % Constructor
        
        function obj = MultiModalMenu(hParent, modules, useModuleAsRoot)
        %MultiModalMenu Create a MultiModalMenu object 
        %
        %   obj = MultiModalMenu(appHandle, modules) creates a
        %   MultiModalMenu for a given app. appHandle is a handle for the 
        %   app and modules is a cell array containing folder 
        %   packages to include when building the menu
        %

            if ~nargin; return; end

            obj.assignParent(hParent)

            if nargin < 2
                modules = {''};
            end

            if nargin < 3 || isempty(useModuleAsRoot)
                useModuleAsRoot = false;
            end

            obj.PackageModules = modules;
            obj.UseModuleAsRoot = useModuleAsRoot;

            % Todo: These should be set when current project is set...
            obj.assignDefaultMethodsPath()
            
            % Todo: Improve performance!
            obj.buildMenuFromDirectory(obj.Figure);

            obj.assignKeyEventListeners()
            obj.Mode = obj.DefaultMode;
        end

        function delete(obj)
            isdeletable = @(x) ~isempty(x) & isvalid(x);
            if isdeletable(obj.hMenuItems)
                delete(obj.hMenuItems)
            end
            if isdeletable(obj.hMenuDirs)
                delete(obj.hMenuDirs)
            end
            if isdeletable(obj.KeyReleasedListener)
                delete(obj.KeyReleasedListener)
            end
            if isdeletable(obj.KeyPressListener)
                delete(obj.KeyPressListener)
            end            
        end
    end

    methods % Set/get
        
        function set.Mode(obj, newMode)
            mustBeMember(newMode, obj.ValidModes)
            if ~isequal(newMode, obj.Mode)
                obj.Mode = newMode;
                obj.refreshMenuLabels()
            end
        end

        function refreshMenuLabels(obj)
        %refreshMenuLabels Callback for changing menu labels.
        %
        %   Invoked when the TaskMode property changes
        
            persistent keyNames modeToKeyLabels

            if isempty(keyNames)
                keyNames = obj.KEY_TO_MODE_MAP.keys();
                
                isShift = cellfun(@(c) strcmp(c, 'shift'), keyNames, 'UniformOutput', true);
                keyNames(isShift) = {'...'};
                keyNames(~isShift) = cellfun(@(c) sprintf(' (%s)', c), keyNames(~isShift), 'UniformOutput', false);

                modeToKeyLabels = containers.Map();
                allModes = obj.KEY_TO_MODE_MAP.values();
                
                for i = 1:numel(keyNames)
                    modeToKeyLabels(allModes{i}) = keyNames{i};
                end

            end

            newKeyLabel = modeToKeyLabels(obj.Mode);

            % Go through all menu items
            for i = 1:numel(obj.hMenuItems)
                
                h = obj.hMenuItems(i);
                
                % Reset the modifier label for all menu items
                for j = 1:numel(keyNames)
                    h.Text = strrep(h.Text, keyNames{j}, '');
                end
                
                % Re-enable (if item was disabled)
                h.Enable = 'on';

                % Append modifier label to menu item text for new mode
                if strcmp(obj.Mode, obj.DefaultMode)
                    % Do nothing...
                else
                    h.Text = sprintf('%s%s',h.Text, newKeyLabel);
                end
            end
        end
        
    end

    methods (Access = protected)

        function refresh(obj)
        %refresh Refresh the menu. Delete all items and recreate them.

            delete( obj.hMenuDirs )
            delete( obj.hMenuItems )
            
            obj.hMenuDirs = matlab.ui.container.Menu.empty;
            obj.hMenuItems = matlab.ui.container.Menu.empty;
            
            obj.buildMenuFromDirectory(obj.Figure);
        end

        function refreshMenuItem(obj, menuName)
            % menuName or functionName ?
            % Todo...
        end

        function addMenuItemForFile(obj, hParent, mFilePath)
        %addMenuItemForFunctionTask Add menu item for a function-based task
        %
        %   Similar to a class based task, but instead of making a submenu
        %   if multiple options are available, a submenu is created if
        %   multiple alternatives are available. An alternative is
        %   different than options in that alternatives are not managed by
        %   the options manager.

            [~, fileName] = fileparts(mFilePath);
            functionName = abspath2funcname(mFilePath);

            menuName = varname2label(fileName);
            iSubMenu = uimenu(hParent, 'Text', menuName);

            obj.createMenuCallback(iSubMenu, functionName)
            obj.storeMenuObject(iSubMenu, functionName)
        end


    end

    methods (Access = private) % Methods for changing mode...
        
        
        
    end

    methods (Access = private) % Methods for initializing & configuring menu
        
        function assignParent(obj, hParent)
        %assignParent Assign the Figure property from a parent handle

            if isa(hParent, 'matlab.ui.Figure')
                obj.Figure = hParent;

            % If hParent is a handle to an app with a Figure property
            elseif isprop(hParent, 'Figure')
            
                obj.ParentApp = hParent;
                obj.Figure = obj.ParentApp.Figure;
            else
                error('MultiModalMenu:InvalidInput', 'The first input must be a valid figure')
            end

            assert(~isempty(obj.Figure) && isvalid(obj.Figure), ...
                    'The provided parent is not a valid figure')
        end

        function assignDefaultMethodsPath(obj)
        %assignDefaultMethodsPath Assign the default path(s) for packages
        %
        %   Get the absolute path of each module containing items and 
        %   assign it to the property DefaultMethodsPath.

            if isempty(obj.PackageModules)
                obj.DefaultMethodsPath = '';
                return
            end
            
            numModules = numel(obj.PackageModules);
            obj.DefaultMethodsPath = cell(numModules, 1);

            for iModule = 1:numModules
                iModuleName = obj.PackageModules{iModule};

                % If the path of a package was given
                if isfolder(iModuleName)
                    obj.DefaultMethodsPath{iModule} = iModuleName;

                % Else: The name of a package was given, resolve path
                else
                    iModuleName = replace(iModuleName, '.', filesep);
    
                    s = what(iModuleName);
                    
                    if numel(s) > 1
                        warning('Multiple matches where found for the module "%s", selecting the first match', iModuleName)
                    end
    
                    obj.DefaultMethodsPath{iModule} = s(1).path;
                end
            end
        end
        
        function assignKeyEventListeners(obj)
            
            import om.external.fex.findjobj.findjobj

            obj.KeyPressListener = listener(obj.Figure, ...
                'WindowKeyPress', @obj.onKeyPressed);
            obj.KeyReleasedListener = listener(obj.Figure, ...
                'WindowKeyRelease', @obj.onKeyReleased);

            [~, hJ] = evalc('findjobj(obj.Figure)');
            hJ(2).KeyPressedCallback = @obj.onKeyPressed;
            hJ(2).KeyReleasedCallback = @obj.onKeyReleased;
        end

        function buildMenuFromDirectory(obj, hParent, dirPath)
        %buildMenuFromDirectory Build menu items from a directory tree
        %
        % Go recursively through a directory tree of matlab packages 
        % and create a menu item for each matlab function which is found 
        % inside. The menu item is configured to trigger an event when it
        % is selected.

        % Requires: 
        %   om.internal.strutil.varname2label (utility.string.varname2label)

            if nargin < 3
                dirPath = obj.DefaultMethodsPath;
                isRootDirectory = true;
            else
                isRootDirectory = false;
            end
        
            if isRootDirectory && obj.UseModuleAsRoot
                [folders, names] = fileparts(dirPath);
                L = struct('folder', folders, 'name', names, 'isdir', true);
               
            else
                % List contents of directory given as input
                L = localMultiDir(dirPath);
            end
            
            if isRootDirectory % Sort listing by names
                % Sort names to come in a specified order...
                [~, sortIdx] = obj.sortMenuNames( {L.name} );
                L = L( sortIdx );
            end
            
            % Loop through contents of directory/directories
            for i = 1:numel(L)
                
                % For folders, add submenu
                if L(i).isdir
                    isPackageFolder = strncmp( L(i).name, '+', 1);
                    
                    if isPackageFolder
                        if ~any( strcmpi(obj.DirectoryIgnore, L(i).name) )
                            obj.addSubmenuForPackageFolder( hParent, L(i) );
                        end
                    else
                        continue
                    end

                % For m-files, add submenu item with callback
                else
                    [~, ~, ext] = fileparts(L(i).name);
                    
                    if ~strcmp(ext, '.m') && ~strcmp(ext, '.mlx')  
                        continue % Skip files that are not .m
                    end

                    mFilePath = fullfile(L(i).folder, L(i).name);
                    obj.addMenuItemForFile(hParent, mFilePath)
                end
            end
        end
        
        function addSubmenuForPackageFolder(obj, hParent, folderListing)
        %addSubmenuForPackageFolder Add submenu for a package folder    
        %
        %   addSubmenuForPackageFolder(obj, hParent, folderListing) adds a
        %   submenu under the given parent menu for a package folder.
        %
        %   Inputs:
        %       hParent : handle to a menu item
        %       folderListing : scalar struct of folder attributes as
        %           returned from the dir function.
            
            % Create a text label for the menu
            menuName = strrep(folderListing.name, '+', '');
            menuName = varname2label(menuName);
            
            % Check if menu with this label already exists
            hMenuItem = findobj( hParent, 'Type', 'uimenu', '-and', ...
                                 'Text', menuName, '-depth', 1 );
            
            % Create new menu item if menu with this label does not exist
            if isempty(hMenuItem)
                hMenuItem = uimenu(hParent, 'Text', menuName);
                obj.hMenuDirs(end+1) = hMenuItem;
            end
            
            % Recursively build a submenu for the package directory
            subDirPath = fullfile(folderListing.folder, folderListing.name);
            obj.buildMenuFromDirectory(hMenuItem, subDirPath)
        end
        
        function createMenuCallback(obj, hMenu, functionName, varargin)
        %createMenuCallback Create a menu callback for the menu item.
        %
        %   If there is a keyword, add it as an input to the callback
        %   function (todo...)
            
            callbackFcn = @(s, e, h, vararg) obj.onMenuSelected(...
                functionName, varargin{:});

            hMenu.MenuSelectedFcn = callbackFcn;
        end

        function storeMenuObject(obj, hMenuItem, functionName)
        %storeMenuObject Store the menuobject in class properties

            numItems = numel(obj.hMenuItems) + 1;

            % Add handle to menu item to property.
            obj.hMenuItems(numItems) = hMenuItem;

            obj.FunctionalItems(numItems).Name = hMenuItem.Text;
            obj.FunctionalItems(numItems).FunctionName = functionName;
        end
    
        function [sortedNames, sortIdx] = sortMenuNames(obj, menuNames)
        %sortMenuNames Sort names in the order of the MenuOrder property
            
            sortIdx = zeros(1, numel(menuNames));
            count = 0;

            for i = 1:numel( obj.MenuOrder )
                
                isMatch = strcmp(obj.MenuOrder{i}, menuNames);
                numMatch = sum(isMatch);

                insertIdx = count + (1:numMatch);
                sortIdx(insertIdx) = find(isMatch);

                count = count + numMatch;
            end
            
            % Put custom names at the end...
            unsortedIdx = setdiff( 1:numel(menuNames), sortIdx(sortIdx~=0) );
            sortIdx(sortIdx == 0) = unsortedIdx;
            
            sortedNames = menuNames(sortIdx);
        end
    end

    methods (Access = private) % Callback

        function onMenuSelected(obj, functionName, varargin)
        %onMenuSelected Callback for menu item selection. Trigger event
        %
        %   Create event data containing mode and task attributes ++ and
        %   trigger the MethodSelected event.

            %params = struct;
            %params.Mode = obj.Mode;

            currentMode = obj.Mode;
            obj.Mode = obj.DefaultMode;
            obj.IsModeLocked = true;
            pause(0.5) % Add some buffer time to avoid "sticky" keys

            if ~isempty(obj.MenuSelectedFcn)
                obj.MenuSelectedFcn(functionName, currentMode)
            end

% %             params = utility.parsenvpairs(params, 1, varargin);
% %             nvPairs = utility.struct2nvpairs(params);
            
            %evtData = uiw.event.EventData( nvPairs{:} );
            %obj.notify('MethodSelected', evtData)

            obj.IsModeLocked = false;
        end
    
        function onKeyPressed(obj, ~, evt)

            if isa(evt, 'java.awt.event.KeyEvent')
                evt = javaKeyEventToMatlabKeyData(evt); % local function
            end
            
            if obj.KEY_TO_MODE_MAP.isKey( evt.Key )

                if ~obj.IsModeLocked
                    obj.Mode = obj.KEY_TO_MODE_MAP( evt.Key );
                end
            end
        end

        function onKeyReleased(obj, ~, evt)

            if isa(evt, 'java.awt.event.KeyEvent')
                evt = javaKeyEventToMatlabKeyData(evt);
            end
            
            if obj.KEY_TO_MODE_MAP.isKey( evt.Key )
                obj.Mode = obj.DefaultMode;
            end
        end
    
    end
    
end


%% Local functions


function L = localMultiDir(name)
%localMultiDir Same as builtin dir, but name can be a cell array
%
%   L = localMultiDir(name)

    if isa(name, 'cell')
        L = cellfun(@(iName) dir(iName), name, 'uni', 0);
        L = cat(1, L{:});
    else
        L = dir(name);
    end
    
    L = L(~strncmp({L.name}, '.', 1));
end

function label = varname2label(varname, includePackageName)
% Convert a camelcase variable name to a label where each word starts with
% capital letter and is separated by a space.
%
%   label = varname2label(varname) insert space before capital letters and
%   make first letter capital
%
%   Example:
%   label = varname2label('helloWorld')
%   
%   label = 
%       'Hello World'

% Todo:
%   How to format names containing . ?

if nargin < 2
    includePackageName = false;
end

% If variable is passed, get the variable name:
if ~ischar(varname); varname = inputname(1); end

% Special case if varname is a package name
if contains(varname, '.') 
    splitVarname = strsplit(varname, '.');
    if includePackageName
        splitVarname = cellfun(@(c) varname2label(c), splitVarname, 'uni', 0);
        label = strjoin(splitVarname, '-');
        return
    else
        varname = splitVarname{end}; % select last item of package name
    end
end


% Insert spaces
if issnakecase(varname)

    label = strrep(varname, '_', ' ');
    
    [strInd] = regexp(label, ' ');
    strInd = [0, strInd] + 1;
    
    for i = strInd
        label(i) = upper(label(i));
    end
    
elseif iscapitalized(varname)
    label = varname;

elseif iscamelcase(varname)
    
    % Insert space after a uppercase letter preceded by a lowercase letter
    % OR before a uppercase letter succeded by a lowercase letter
    % ie aB = 'a B' and AAb = A Ab
    
    expression = '((?<=[a-z])[A-Z])|([A-Z](?=[a-z]))';
    varname = regexprep(varname, expression, ' $0');
    
% % %     capLetterStrInd = regexp(varname, '[A-Z, 1-9]');
% % %     prevI = [];
% % %     for i = fliplr(capLetterStrInd)
% % %         if i ~= 1 %Skip space before first letter if PascalCase
% % %             varname = insertBefore(varname, i , ' ');
% % %         end
% % %         prevI = i;
% % %     end

    varname(1) = upper(varname(1));
    label = varname;
    
else
    varname(1) = upper(varname(1));
    label = varname;
end

label = strtrim(label);


end

function isCamelCase = iscamelcase(varname)
    
    capLetterStrInd = regexp(varname, '[A-Z]');
    if any(capLetterStrInd > 1)
        isCamelCase = true;
    else
        isCamelCase = false;
    end
    
end

function isSnakeCase = issnakecase(varname)
    isSnakeCase = contains(varname, '_');
end

function isCapitalized = iscapitalized(varname)
    isCapitalized = strcmp(varname, upper(varname)); %#ok<STCI>
end

function functionName = abspath2funcname(pathStr)
%abspath2func Get function name for mfile given as pathstr

    % Get function name, taking package into account
    [folderPath, functionName, ext] = fileparts(pathStr);
    
    assert(strcmp(ext, '.m'), 'pathStr must point to a .m (function) file')
    
    packageName = pathstr2packagename(folderPath); % Local function
    functionName = strcat(packageName, '.', functionName);
    
    
    % Add package-containing folder to path if it is not...
    
    %fcnHandle = str2func(functionName);

end

function mEvt = javaKeyEventToMatlabKeyData(jEvt)
%javaKeyEventToMatlabKeyData Cast java keyevent to matlab event keydata
%
%   Properties of matlab event Keydata:
%    - Character  : Case sensitive
%    - Modifier   : 
%    - Key        : Lower version of a letter
    
    % Todo: What about keys that are not letters
    %       What about windows?
    
    
    %% Get the character
    mEvt.Character = get(jEvt, 'KeyChar');
    
    % Remove special characters...
    if double(mEvt.Character) == (2^16 - 1)
        mEvt.Character = '';
    end
    
    
    %% Get the modifier(s)
    mEvt.Modifier = getModifiers(jEvt);

    
    %% Get the key name
    mEvt.Key = lower( get(jEvt, 'KeyChar') );
    
    % Add key name for non-character keys.
    if double(mEvt.Key) == (2^16 - 1)
        mEvt.Key = getSpecialKey(jEvt);
    end
    
    
    %% For debugging
    if false
        get(jEvt)
    end
    
end


function cellOfModifiers = getModifiers(jEvt)

    cellOfModifiers = cell(0,1);
    
    if get(jEvt, 'ShiftDown') == 1
        cellOfModifiers{end+1} = 'shift'; 
    end
    
    if get(jEvt, 'ControlDown') == 1
        cellOfModifiers{end+1} = 'control'; 
    end
        
    if get(jEvt, 'AltDown') == 1
        cellOfModifiers{end+1} = 'alt'; 
    end
    
    if get(jEvt, 'MetaDown') == 1
        cellOfModifiers{end+1} = 'command';
    end
    
end

function keyName = getSpecialKey(jEvt)

    % Todo: Add mode cases...
    
    keyCode = get(jEvt, 'KeyCode');

    switch keyCode
        case 16
            keyName = 'shift';
        case 17
            keyName = 'control';
        case 18
            keyName = 'alt';
        case 157
            keyName = 'command';
            
        otherwise
            keyName = '';
    end
    
end


function packageName = pathstr2packagename(pathStr)
%pathstr2packagename Convert a path string to a string with name of package
%
%       packageName = pathstr2packagename(pathStr)
%
%   EXAMPLE:
% 
%    pathStr =
%       '/Users/eivinhen/PhD/Programmering/MATLAB/VervaekeLab_Github/NANSEN/code/+nansen/+session/+methods/+data/+open'
%
%    packageName = utility.path.pathstr2packagename(pathStr)
%
%    packageName =
%       'nansen.session.methods.data.open'


    assert(isfolder(pathStr), 'Path must point to a folder.')
       
    % Split pathstr by foldernames
    splitFolderNames = strsplit(pathStr, filesep);
    
    % Find all folders that are a package
    isPackage = cellfun(@(str) strncmp(str, '+', 1), splitFolderNames );
    
    % Create output string
    packageFolderNames = splitFolderNames(isPackage);
    packageFolderNames = strrep(packageFolderNames, '+', '');
    
    packageName = strjoin(packageFolderNames, '.');

end