classdef InstanceTypeMenu < handle & matlab.mixin.SetGet
% InstanceTypeMenu Provides a context menu for selecting openMINDS types
%
%   Attaches a context menu to the given figure which provides openMINDS
%   types as options. Note: Types must be set upon creation of the menu
%
%   Example usage:
%
%   om.internal.container.InstanceTypeMenu(hFigure,
%       Types=["Person", "Organization"], ...
%       SelectedType="Person" )

    properties (SetAccess = immutable)
        % Types - A list of types to select from (options)
        Types (1,:) openminds.enum.Types
    end

    properties (AbortSet)
        % SelectedType - The currently selected type
        SelectedType (1,1) openminds.enum.Types
    end

    properties
        % SelectionChangedFcn - Function handle for function to call when a
        % type is selected. The function will receive to inputs, the source
        % of the interaction, i.e an object of this class, and an eventdata
        % object. See: om.internal.event.SelectedTypeChangedData
        SelectionChangedFcn
    end

    properties (Access = private)
        UIContextMenu
    end

    % Constructor
    methods
        function obj = InstanceTypeMenu(hFigure, options)
            arguments
                hFigure matlab.ui.Figure
                options.?om.internal.container.InstanceTypeMenu
                options.Types (1,:) openminds.enum.Types
            end

            if isfield(options, 'Types')
                obj.Types = options.Types;
                obj.createContextMenu(hFigure)
                options = rmfield(options, 'Types');
            end

            obj.set(options)
        end
    end

    % Public methods
    methods
        function open(obj, x, y)
            obj.UIContextMenu.open(x, y)
        end
    end

    % Set methods for properties
    methods
        function set.SelectedType(obj, value)
            value = obj.validateActiveType(value);
            obj.SelectedType = value;
            obj.postSetSelectedType()
        end
    end

    % Postset methods for properties
    methods (Access = private)
        function postSetSelectedType(obj)
            obj.updateCheckedContextMenuItem()
            if ~isempty(obj.SelectionChangedFcn)
                evtData = om.internal.event.SelectedTypeChangedData(obj.SelectedType);
                obj.SelectionChangedFcn(obj, evtData)
            end
        end
    end

    % Component callback methods
    methods (Access = private)
        function onContextMenuItemClicked(obj, ~, event)
            obj.SelectedType = openminds.enum.Types(event.Source.Text);
        end
    end

    % Creation and internal updates
    methods (Access = private)

        % Create context menu for selecting active type
        function createContextMenu(obj, hFigure)
        % createContextMenu - Create context menu for selecting active type

            if ~isempty(hFigure) && isvalid(hFigure)
                if isempty(obj.UIContextMenu)
                    obj.UIContextMenu = uicontextmenu(hFigure);
                end

                if ~isempty(obj.UIContextMenu.Children)
                    delete(obj.UIContextMenu.Children)
                end

                for i = 1:numel(obj.Types)
                    typeName = obj.Types(i).getSchemaName();
                    typeMenuItem = uimenu(obj.UIContextMenu);
                    typeMenuItem.Text = typeName;
                    typeMenuItem.Callback = @obj.onContextMenuItemClicked;
                    typeMenuItem.Checked = 'off';
                end
            end
        end

        function updateCheckedContextMenuItem(obj)
            % Uncheck all menu items
            set(obj.UIContextMenu.Children, 'Checked', 'off');

            if ismissing(obj.SelectedType)
                % pass
            else
                menuItemLabels = {obj.UIContextMenu.Children.Text};
                selectedTypeName = obj.SelectedType.getSchemaName();

                isMatch = strcmp(menuItemLabels, selectedTypeName);
                if any(isMatch)
                    obj.UIContextMenu.Children(isMatch).Checked = "on";
                else
                    error('Unexpected')
                end
            end
        end

        function value = validateActiveType(obj, value)
        % validateActiveType - Validate value for ActiveType property

            isValid = any( obj.Types == value );

            errorMessage = sprintf( 'Selected type must be any of: %s', ...
                    strjoin(string(obj.Types), ', '));

            assert(isValid, errorMessage)
        end
    end
end
