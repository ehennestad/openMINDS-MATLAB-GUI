classdef SchemaMenu < MultiModalMenu
%SchemaMenu The schema menu is used for creating open minds schema instances
%
%   The schema menu is created based on a folder structure containing
%   schema definitions. 
%
%   The schema menu is multimodal, meaning the user can apply modifier keys
%   to adapt the behavior/mode when selecting items from the menu
    
    
    properties (Constant, Hidden) % Todo: Abstract
        ValidModes = {'Single', 'Multiple', 'Help', 'Open', 'View'}                 % Available modes
        DefaultMode = 'View'
        MenuOrder = {'+core', '+controlledterms'}              % Todo: preference?
    end

    properties % Todo: Inherit from a superclass (folder to menu?)
        RootDirectory = '';
        DirectoryIgnore = {'+category', '+linkedcategory'}
    end
    

    properties (Constant, Hidden)
        KEY_TO_MODE_MAP = containers.Map( {'', 'n', 'h', 'o', 'v'}, {'View', 'Multiple', 'Help', 'Open', 'Single'})
    end


    methods
        function obj = SchemaMenu(hParent, moduleSet, useModuleAsRoot)
            if nargin < 3; useModuleAsRoot = false; end
            obj@MultiModalMenu(hParent, moduleSet, useModuleAsRoot)
        end
    end
    
    methods (Access = protected)
        
        function addMenuItemForFile(obj, hParent, mFilePath)

            functionName = abspath2funcname(mFilePath);

            mc = meta.class.fromName(functionName);
            if mc.Abstract
                return
            else
                addMenuItemForFile@MultiModalMenu(obj, hParent, mFilePath)
            end
        end
    end
end


%% Local functions 

function functionName = abspath2funcname(pathStr)
%abspath2func Get function name for mfile given as pathstr

    % Get function name, taking package into account
    [folderPath, functionName, ext] = fileparts(pathStr);
    
    assert(strcmp(ext, '.m'), 'pathStr must point to a .m (function) file')
    
    packageName = om.internal.strutil.pathstr2packagename(folderPath);
    functionName = strcat(packageName, '.', functionName);
    
    
    % Add package-containing folder to path if it is not...
    
    %fcnHandle = str2func(functionName);

end