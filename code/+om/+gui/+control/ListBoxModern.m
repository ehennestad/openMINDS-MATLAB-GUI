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
        ContextMenu         % Context menu for right-click actions
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
            
            % Create context menu
            obj.createContextMenu();
            
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
        function createContextMenu(obj)
            % Create context menu for the listbox
            fig = ancestor(obj.Panel, 'figure');
            obj.ContextMenu = uicontextmenu(fig);
            obj.UIListBox.ContextMenu = obj.ContextMenu;
            
            % Set the opening callback to handle selection on right-click
            obj.ContextMenu.ContextMenuOpeningFcn = @obj.onContextMenuOpening;
            
            % Add "Remove Item" menu item
            uimenu(obj.ContextMenu, ...
                'Text', 'Remove Item', ...
                'MenuSelectedFcn', @obj.onRemoveItem);
            
            % Add "Remove All Items" menu item
            uimenu(obj.ContextMenu, ...
                'Text', 'Remove All Items', ...
                'MenuSelectedFcn', @obj.onRemoveAllItems, ...
                'Separator', 'on');
        end
        
        function onContextMenuOpening(obj, ~, evt)
            % Handle selection when context menu is opened (right-click)
            % Right-clicking an item selects it and updates the table.
            % This matches standard UX behavior where right-click means
            % "work with this item" and shows the context menu.
            
            % Get the figure to check selection type (normal vs shift-click)
            hFigure = ancestor(obj.UIListBox, 'figure');
            
            % Determine which item was clicked
            clickedItem = obj.getClickedItem(evt);
            
            if isempty(clickedItem)
                return; % Click outside valid area
            end
            
            % Update selection based on click type
            % NOTE: Callbacks are NOT suppressed - table will update to show the selected item
            if strcmp(hFigure.SelectionType, 'extend')
                % Shift+Right-Click: Extend selection
                obj.extendSelectionTo(clickedItem);
            else
                % Normal right-click: Select only if not already selected
                currentSelection = obj.SelectedItems;
                if ~ismember(clickedItem, currentSelection)
                    obj.SelectedItems = clickedItem;
                end
            end
        end
        
        function clickedItem = getClickedItem(obj, evt)
            % Determine which item was right-clicked using InteractionInformation
            
            clickedItem = '';
            
            try
                % Get the clicked item index from InteractionInformation
                clickedIdx = evt.InteractionInformation.Item;
                
                if isempty(clickedIdx) || clickedIdx < 1 || clickedIdx > numel(obj.Name)
                    return;
                end
                
                % Return the item name at the clicked index
                clickedItem = obj.Name{clickedIdx};
            catch
                % If we can't determine clicked item, fall back to current selection
                currentSel = obj.SelectedItems;
                if ~isempty(currentSel)
                    clickedItem = currentSel{1};
                end
            end
        end
        
        function extendSelectionTo(obj, targetItem)
            % Extend selection from current selection to target item
            % Similar to UIMetaTable's shift-click behavior
            
            currentSelection = obj.SelectedItems;
            if isempty(currentSelection)
                obj.SelectedItems = targetItem;
                return;
            end
            
            % Find indices of current selection and target
            allItems = obj.Name;
            currentIndices = cellfun(@(x) find(strcmp(allItems, x), 1), ...
                currentSelection, 'UniformOutput', true);
            targetIdx = find(strcmp(allItems, targetItem), 1);
            
            if isempty(targetIdx)
                return;
            end
            
            % Create selection range
            minIdx = min([currentIndices, targetIdx]);
            maxIdx = max([currentIndices, targetIdx]);
            
            obj.SelectedItems = allItems(minIdx:maxIdx);
        end
        
        function onRemoveItem(obj, ~, ~)
            % Remove currently selected item(s) from the listbox
            if isempty(obj.SelectedItems)
                return;
            end
            
            % Get current items
            currentItems = obj.UIListBox.ItemsData;
            currentLabels = obj.UIListBox.Items;
            
            % Find items to keep (not selected)
            itemsToRemove = obj.SelectedItems;
            keepMask = true(size(currentItems));
            for i = 1:numel(itemsToRemove)
                keepMask = keepMask & ~strcmp(currentItems, itemsToRemove{i});
            end
            
            % Update the listbox
            if any(keepMask)
                obj.UIListBox.ItemsData = currentItems(keepMask);
                obj.UIListBox.Items = currentLabels(keepMask);
                obj.Name = currentItems(keepMask);
                if ~isempty(obj.Icon)
                    obj.Icon = obj.Icon(keepMask);
                end
                
                % Select the first remaining item
                if ~isempty(obj.Name)
                    obj.SelectedItems = obj.Name(1);
                end
            else
                % No items left
                obj.UIListBox.ItemsData = {};
                obj.UIListBox.Items = {};
                obj.Name = {};
                obj.Icon = {};
            end
        end
        
        function onRemoveAllItems(obj, ~, ~)
            % Remove all items from the listbox
            obj.UIListBox.ItemsData = {};
            obj.UIListBox.Items = {};
            obj.Name = {};
            obj.Icon = {};
        end
        
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

