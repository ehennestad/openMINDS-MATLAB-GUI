classdef ListBoxModern < handle
%ListBoxModern Modern web-based listbox widget for MATLAB R2023a+
%
%   This implementation uses uilistbox which handles resizing automatically
%   and provides better performance than custom graphics-based solutions.

    properties
        % Whether single or multiple items in the list can be selected
        SelectionMode char {mustBeMember(SelectionMode, {'single', 'multiple'})} = 'multiple'
    end

    properties
        Items               % List (cell array) of items to display
        SelectionChangedFcn % Function handle to invoke when selected item changes
    end

    properties (Access = private)
        Name % List of names for each list item
        Icon % List of icons for each list item
    end

    properties % Appearance
        FontName = 'Helvetica';
        FontSize = 15;
        ItemPadding = 2; % Additional vertical padding (in pixels, approximate)
    end

    properties (SetAccess = private)
        Panel               % Parent panel
        UIListBox           % MATLAB uilistbox component
    end

    properties (Dependent)
        SelectedItems
    end

    methods
        function obj = ListBoxModern(hPanel, items)
            
            obj.Panel = hPanel;
            obj.Items = items;

            if isa(items, 'cell')
                obj.Name = items;
                obj.Icon = cell(size(obj.Name));
            elseif isa(items, 'struct')
                obj.Name = items.Name;
                obj.Icon = items.Icon;
            end

            % Convert names to labels
            itemLabels = cellfun(@(c) om.internal.strutil.varname2label(c), ...
                obj.Name, 'UniformOutput', false);
            
            % Create the uilistbox
            obj.UIListBox = uilistbox(obj.Panel, ...
                'Items', itemLabels, ...
                'ItemsData', obj.Name, ...
                'Multiselect', strcmp(obj.SelectionMode, 'multiple'), ...
                'ValueChangedFcn', @obj.onListBoxValueChanged, ...
                'FontName', obj.FontName, ...
                'FontSize', obj.FontSize);
            
            % Set position to fill parent panel (will auto-resize)
            obj.UIListBox.Position = [1, 1, hPanel.Position(3)-2, hPanel.Position(4)-2];
            
            % Select first item by default (without triggering callback yet)
            if ~isempty(obj.Name)
                obj.UIListBox.Value = obj.Name(1);
            end
        end

        function delete(obj)
            if ~isempty(obj.UIListBox) && isvalid(obj.UIListBox)
                delete(obj.UIListBox)
            end
        end
        
        function updateLayout(obj)
        %updateLayout Update layout after panel resize
            % For modern components, this is handled automatically by MATLAB
            % but we can explicitly update if needed
            if ~isempty(obj.UIListBox) && isvalid(obj.UIListBox)
                obj.UIListBox.Position = [1, 1, obj.Panel.Position(3)-2, obj.Panel.Position(4)-2];
            end
        end
    end

    methods % Set/get
        function set.SelectedItems(obj, newValue)
            if ischar(newValue)
                newValue = {newValue};
            end
            
            % Get old value before changing
            oldValue = obj.UIListBox.Value;
            
            % Set new value
            if strcmp(obj.SelectionMode, 'single')
                obj.UIListBox.Value = newValue(1);
            else
                obj.UIListBox.Value = newValue;
            end
            
            % Manually trigger the callback since programmatic changes 
            % don't trigger ValueChangedFcn
            if ~isempty(obj.SelectionChangedFcn)
                % Create event data
                if isempty(oldValue)
                    oldSelection = {};
                elseif ischar(oldValue) || isstring(oldValue)
                    oldSelection = {char(oldValue)};
                else
                    oldSelection = cellstr(oldValue);
                end
                
                newSelection = newValue;
                if ~iscell(newSelection)
                    newSelection = {newSelection};
                end
                
                evtData = om.gui.event.ItemSelectionEventData(oldSelection, newSelection);
                obj.SelectionChangedFcn(obj, evtData);
            end
        end

        function selectedItems = get.SelectedItems(obj)
            if isempty(obj.UIListBox) || ~isvalid(obj.UIListBox)
                selectedItems = {};
                return;
            end
            
            value = obj.UIListBox.Value;
            if ischar(value) || isstring(value)
                selectedItems = {char(value)};
            else
                selectedItems = cellstr(value);
            end
        end
    end

    methods (Access = private)
        function onListBoxValueChanged(obj, ~, evt)
            % Get old and new selection
            if isempty(evt.PreviousValue)
                oldSelection = {};
            elseif ischar(evt.PreviousValue) || isstring(evt.PreviousValue)
                oldSelection = {char(evt.PreviousValue)};
            else
                oldSelection = cellstr(evt.PreviousValue);
            end
            
            if isempty(evt.Value)
                newSelection = {};
            elseif ischar(evt.Value) || isstring(evt.Value)
                newSelection = {char(evt.Value)};
            else
                newSelection = cellstr(evt.Value);
            end
            
            % Call the SelectionChangedFcn if present
            if ~isempty(obj.SelectionChangedFcn)
                evtData = om.gui.event.ItemSelectionEventData(oldSelection, newSelection);
                obj.SelectionChangedFcn(obj, evtData);
            end
        end
    end
end

