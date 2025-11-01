classdef HasDialogs < handle
    
    properties (SetAccess=immutable)
        FigureHandlePropertyName (1,1) string = "Figure"
    end

    methods
        function obj = HasDialogs(figureName)
        % HasDialogs - Creates an object for managing dialog windows.
        %
        % Syntax:
        %   obj = HasDialogs(figureName) Creates a dialog manager object for the
        %   specified figure.
        %
        % Input Arguments:
        %   figureName - The name of the figure for which dialog management is
        %   to be handled.
        %
        % Output Arguments:
        %   obj - An instance of the HasDialogs object that manages dialog
        %   interactions for the specified figure.

            arguments
                figureName (1,1) string = "Figure"
            end
            obj.FigureHandlePropertyName = figureName;
        end
    end

    methods (Access = protected)
        
        function uialert(obj, message, title, options)
        % uialert - Display alert dialog box
        %
        % Syntax:
        %   uialert(obj, message, title)
        %   uialert(obj, message, title, Name, Value)
        %
        % Input Arguments:
        %   message - Alert message (character vector or string)
        %   title - Dialog title (character vector or string)
        %   Name-Value pairs:
        %       Icon - 'info', 'warning', 'error', 'success', or 'question'
        %       CloseFcn - Callback function when dialog closes
        %       Modal - true (default) or false
        
            arguments
                obj
                message {mustBeTextScalar}
                title {mustBeTextScalar} = "Alert"
                options.Icon {mustBeMember(options.Icon, ...
                    ["info", "warning", "error", "success", "question"])} = "info"
                options.CloseFcn = []
                options.Modal (1,1) logical = true
            end
            
            figHandle = obj.(obj.FigureHandlePropertyName);
            
            args = {'Icon', options.Icon, 'Modal', options.Modal};
            if ~isempty(options.CloseFcn)
                args = [args, {'CloseFcn', options.CloseFcn}];
            end
            
            uialert(figHandle, message, title, args{:});
        end
        
        function inform(obj, message, title, options)
        % inform - Display informational alert dialog
        %
        % Syntax:
        %   alert = inform(obj, message)
        %   alert = inform(obj, message, title)
        %   alert = inform(obj, message, title, Name, Value)
        %
        % Input Arguments:
        %   message - Alert message (character vector or string)
        %   title - Dialog title (character vector or string)
        %   Name-Value pairs:
        %       CloseFcn - Callback function when dialog closes
        %       Modal - true (default) or false
        
            arguments
                obj
                message {mustBeTextScalar}
                title {mustBeTextScalar} = "Information"
                options.CloseFcn = []
                options.Modal (1,1) logical = true
            end
            
            obj.uialert(message, title, ...
                'Icon', 'info', ...
                'CloseFcn', options.CloseFcn, ...
                'Modal', options.Modal);
        end
        
        function warn(obj, message, title, options)
        % warn - Display warning alert dialog
        %
        % Syntax:
        %   alert = warn(obj, message)
        %   alert = warn(obj, message, title)
        %   alert = warn(obj, message, title, Name, Value)
        %
        % Input Arguments:
        %   message - Warning message (character vector or string)
        %   title - Dialog title (character vector or string)
        %   Name-Value pairs:
        %       CloseFcn - Callback function when dialog closes
        %       Modal - true (default) or false
        
            arguments
                obj
                message {mustBeTextScalar}
                title {mustBeTextScalar} = "Warning"
                options.CloseFcn = []
                options.Modal (1,1) logical = true
            end
            
            obj.uialert(message, title, ...
                'Icon', 'warning', ...
                'CloseFcn', options.CloseFcn, ...
                'Modal', options.Modal);
        end
        
        function error(obj, message, title, options)
        % error - Display error alert dialog
        %
        % Syntax:
        %   alert = error(obj, message)
        %   alert = error(obj, message, title)
        %   alert = error(obj, message, title, Name, Value)
        %
        % Input Arguments:
        %   message - Error message (character vector or string)
        %   title - Dialog title (character vector or string)
        %   Name-Value pairs:
        %       CloseFcn - Callback function when dialog closes
        %       Modal - true (default) or false
        
            arguments
                obj
                message {mustBeTextScalar}
                title {mustBeTextScalar} = "Error"
                options.CloseFcn = []
                options.Modal (1,1) logical = true
            end
            
            obj.uialert(message, title, ...
                'Icon', 'error', ...
                'CloseFcn', options.CloseFcn, ...
                'Modal', options.Modal);
        end
        
        function [dlg, dlgCleanup] = uiprogressdlg(obj, message, options)
        % uiprogressdlg - Create progress dialog box
        %
        % Syntax:
        %   dlg = uiprogressdlg(obj)
        %   dlg = uiprogressdlg(obj, Name, Value)
        %
        % Input Arguments:
        %   Name-Value pairs:
        %       Title - Dialog title
        %       Message - Progress message
        %       Value - Progress value (0-1)
        %       Indeterminate - 'on' or 'off'
        %       Cancelable - true or false
        %       CancelText - Text for cancel button
        
            arguments
                obj
                message (1,1) string {mustBeTextScalar}
                options.Title {mustBeTextScalar} = "Progress"
                options.Value (1,1) double = 0
                options.Indeterminate {mustBeMember(options.Indeterminate, ...
                    ["on", "off"])} = "off"
                options.Cancelable (1,1) logical = false
                options.CancelText {mustBeTextScalar} = "Cancel"
            end
            
            figHandle = obj.(obj.FigureHandlePropertyName);
            
            args = {'Title', options.Title, ...
                    'Message', message, ...
                    'Value', options.Value, ...
                    'Indeterminate', options.Indeterminate, ...
                    'Cancelable', options.Cancelable};
            
            if options.Cancelable
                args = [args, {'CancelText', options.CancelText}];
            end
            
            dlg = uiprogressdlg(figHandle, args{:});
            if nargout == 2
                dlgCleanup = onCleanup(@() obj.deleteDialog(dlg));
            end
        end
        
        function selection = uiconfirm(obj, message, title, options)
        % uiconfirm - Create confirmation dialog box
        %
        % Syntax:
        %   selection = uiconfirm(obj, message, title)
        %   selection = uiconfirm(obj, message, title, Name, Value)
        %
        % Input Arguments:
        %   message - Dialog message
        %   title - Dialog title
        %   Name-Value pairs:
        %       Options - Cell array of button labels
        %       DefaultOption - Default button (index or label)
        %       CancelOption - Cancel button (index or label)
        %       Icon - 'info', 'warning', 'error', 'success', or 'question'
        
            arguments
                obj
                message {mustBeTextScalar}
                title {mustBeTextScalar} = "Confirm"
                options.Options cell = {'OK', 'Cancel'}
                options.DefaultOption = 1
                options.CancelOption = 2
                options.Icon {mustBeMember(options.Icon, ...
                    ["info", "warning", "error", "success", "question"])} = "question"
            end
            
            figHandle = obj.(obj.FigureHandlePropertyName);
            
            selection = uiconfirm(figHandle, message, title, ...
                'Options', options.Options, ...
                'DefaultOption', options.DefaultOption, ...
                'CancelOption', options.CancelOption, ...
                'Icon', options.Icon);
        end
        
        function [file, path] = uigetfile(obj, options)
        % uigetfile - Open file selection dialog box
        %
        % Syntax:
        %   [file, path] = uigetfile(obj)
        %   [file, path] = uigetfile(obj, Name, Value)
        %
        % Input Arguments:
        %   Name-Value pairs:
        %       FilterSpec - File filter specification
        %       Title - Dialog title
        %       DefaultName - Default file name
        %       MultiSelect - 'on' or 'off'
        
            arguments
                obj %#ok<*INUSA>
                options.FilterSpec = '*.*'
                options.Title {mustBeTextScalar} = "Select File"
                options.DefaultName {mustBeTextScalar} = ""
                options.MultiSelect {mustBeMember(options.MultiSelect, ...
                    ["on", "off"])} = "off"
            end
            
            [file, path] = uigetfile(options.FilterSpec, options.Title, ...
                options.DefaultName, 'MultiSelect', options.MultiSelect);
        end
        
        function [file, path] = uiputfile(obj, options)
        % uiputfile - Save file dialog box
        %
        % Syntax:
        %   [file, path] = uiputfile(obj)
        %   [file, path] = uiputfile(obj, Name, Value)
        %
        % Input Arguments:
        %   Name-Value pairs:
        %       FilterSpec - File filter specification
        %       Title - Dialog title
        %       DefaultName - Default file name
        
            arguments
                obj
                options.FilterSpec = '*.*'
                options.Title {mustBeTextScalar} = "Save File"
                options.DefaultName {mustBeTextScalar} = ""
            end
            
            [file, path] = uiputfile(options.FilterSpec, options.Title, ...
                options.DefaultName);
        end
        
        function folder = uigetdir(obj, options)
        % uigetdir - Folder selection dialog box
        %
        % Syntax:
        %   folder = uigetdir(obj)
        %   folder = uigetdir(obj, Name, Value)
        %
        % Input Arguments:
        %   Name-Value pairs:
        %       StartPath - Starting folder path
        %       Title - Dialog title
        
            arguments
                obj
                options.StartPath {mustBeTextScalar} = pwd
                options.Title {mustBeTextScalar} = "Select Folder"
            end
            
            folder = uigetdir(options.StartPath, options.Title);
        end
        
        function dlg = uisetcolor(obj, options)
        % uisetcolor - Color picker dialog box
        %
        % Syntax:
        %   dlg = uisetcolor(obj)
        %   dlg = uisetcolor(obj, Name, Value)
        %
        % Input Arguments:
        %   Name-Value pairs:
        %       InitialColor - Initial color value (RGB triplet)
        %       Title - Dialog title
        
            arguments
                obj
                options.InitialColor (1,3) double = [0, 0, 0]
                options.Title {mustBeTextScalar} = "Select Color"
            end
            
            dlg = uisetcolor(options.InitialColor, options.Title);
        end
        
        function answer = inputdlg(obj, prompt, title, options)
        % inputdlg - Input dialog box
        %
        % Syntax:
        %   answer = inputdlg(obj, prompt, title)
        %   answer = inputdlg(obj, prompt, title, Name, Value)
        %
        % Input Arguments:
        %   prompt - Cell array of prompt strings
        %   title - Dialog title
        %   Name-Value pairs:
        %       Dims - Dimensions of input fields
        %       DefInput - Default input values
        
            arguments
                obj
                prompt cell
                title {mustBeTextScalar} = "Input"
                options.Dims = [1 35]
                options.DefInput cell = {}
            end
            
            if isempty(options.DefInput)
                answer = inputdlg(prompt, title, options.Dims);
            else
                answer = inputdlg(prompt, title, options.Dims, options.DefInput);
            end
        end
        
        function selection = listdlg(obj, options)
        % listdlg - List selection dialog box
        %
        % Syntax:
        %   selection = listdlg(obj, Name, Value)
        %
        % Input Arguments:
        %   Name-Value pairs:
        %       ListString - Cell array of list items
        %       SelectionMode - 'single' or 'multiple'
        %       ListSize - [width height] in pixels
        %       InitialValue - Initial selection indices
        %       Name - Dialog title
        %       PromptString - Prompt text
        
            arguments
                obj
                options.ListString cell
                options.SelectionMode {mustBeMember(options.SelectionMode, ...
                    ["single", "multiple"])} = "single"
                options.ListSize (1,2) double = [160 300]
                options.InitialValue double = 1
                options.Name {mustBeTextScalar} = "Select"
                options.PromptString = "Select an item:"
            end
            
            [selection, ~] = listdlg('ListString', options.ListString, ...
                'SelectionMode', options.SelectionMode, ...
                'ListSize', options.ListSize, ...
                'InitialValue', options.InitialValue, ...
                'Name', options.Name, ...
                'PromptString', options.PromptString);
        end
    end

    methods (Access = private)
        function deleteDialog(~, dialogHandle)
            if isvalid(dialogHandle)
                delete(dialogHandle)
            end
        end
    end
end
