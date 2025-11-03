classdef UIMetaTable < om.internal.control.abstract.MetaTableViewer
%UIMetaTable Concrete implementation using MATLAB uitable (R2025a+)
%
%   This class implements MetaTableViewer using standard MATLAB uitable
%   component for compatibility with R2025a and newer versions.

% Todo: Save column orders and column widths to persistent column configurations.

    properties (SetAccess = protected)
        Parent          % Parent container
    end
    
    properties (Access = private)
        UITable         % The underlying uitable component
        LastClickTime = 0  % Time of last mouse click (for detecting double-clicks)
    end

    properties (Access = private)
        PrivateTableContextMenu
    end
    
    methods
        function obj = UIMetaTable(varargin)
            %UIMetaTable Construct table viewer
            %
            %   obj = UIMetaTable() creates empty table in new figure
            %   obj = UIMetaTable(parent) creates empty table in parent
            %   obj = UIMetaTable(parent, metaTable) creates with data
            %   obj = UIMetaTable(..., Name, Value) sets properties using
            %       name-value pairs
            %
            %   Compatible with NANSEN MetaTableViewer constructor:
            %       obj = UIMetaTable(parent, metaTable, 'ColumnSettings', settings, ...)
            
            % Parse input arguments flexibly like NANSEN's MetaTableViewer
            obj.parseInputs(varargin);
            
            % Set default parent if not provided
            if isempty(obj.Parent)
                obj.Parent = figure('Name', 'MetaTable Viewer');
            end
            
            % Create UI component
            obj.createTableComponent();
            
            % Set data if provided and update display
            if ~isempty(obj.MetaTable)
                obj.updateTableDisplay();
            end
        end
        
        function parseInputs(obj, args)
            %parseInputs Parse flexible constructor arguments
            %   Handles: (parent, metaTable, Name, Value, ...)
            
            if isempty(args); return; end
            
            % Extract name-value pairs first
            [nvPairs, remainingArgs] = utility.getnvpairs(args);
            
            % Set name-value pairs
            for i = 1:2:numel(nvPairs)
                propName = nvPairs{i};
                propValue = nvPairs{i+1};
                
                % Handle special properties
                if isprop(obj, propName)
                    obj.(propName) = propValue;
                end
            end
            
            if isempty(remainingArgs); return; end
            
            % Check if first argument is a graphical container
            if isgraphics(remainingArgs{1})
                obj.Parent = remainingArgs{1};
                remainingArgs = remainingArgs(2:end);
            end
            
            if isempty(remainingArgs); return; end
            
            % Check if next argument is a table
            if istable(remainingArgs{1}) || isa(remainingArgs{1}, 'nansen.metadata.MetaTable')
                obj.setMetaTable(remainingArgs{1});
                % remainingArgs = remainingArgs(2:end); % Not used further
            end
        end
        
        function rowIndices = getSelectedEntries(obj)
            %getSelectedEntries Get indices of selected rows (data referenced)
            rowIndices = obj.SelectedRows;
        end
        
        function updateCells(obj, rowIndices, columnIndices, newValues)
            %updateCells Update specific cells in the table
            
            if isempty(obj.MetaTable)
                return
            end
            
            % Update underlying data
            for i = 1:numel(rowIndices)
                obj.MetaTable{rowIndices(i), columnIndices(i)} = newValues{i};
            end
            
            % Update display
            obj.updateTableDisplay();
            
            % Notify listeners
            notify(obj, 'DataChanged');
        end
        
        function refreshTable(obj, newMetaTable, ~)
            %refreshTable Refresh table with new or updated data
            %
            %   refreshTable(obj) refreshes with current MetaTable
            %   refreshTable(obj, newMetaTable) sets new data and refreshes
            %   refreshTable(obj, newMetaTable, flushTable) - flushTable ignored for compatibility
            
            if nargin > 1 && ~isempty(newMetaTable)
                obj.setMetaTable(newMetaTable);
            end
            
            obj.updateTableDisplay();
        end
        
        function resetTable(obj)
            %resetTable Reset table to initial state
            % Todo: remove? same as abstract superclass
            obj.SelectedRows = [];
            obj.SelectedColumns = [];
            obj.MetaTable = table.empty;
            obj.updateTableDisplay();
        end
        
        function delete(obj)
            %delete Cleanup
            if ~isempty(obj.UITable) && isvalid(obj.UITable)
                delete(obj.UITable);
            end
            if ~isempty(obj.PrivateTableContextMenu) && isvalid(obj.PrivateTableContextMenu)
                delete(obj.PrivateTableContextMenu);
            end
        end
    end
    
    % Abstract method implementations
    methods (Access = public)
        function createTableComponent(obj)
            %createTableComponent Create the uitable component
            
            % Create uitable
            obj.UITable = uitable(obj.Parent);
            obj.UITable.Units = 'normalized';
            obj.UITable.Position = [0 0 1 1];
            obj.UITable.SelectionType = "row";
            obj.UITable.ColumnSortable = true;

            % Set callbacks
            obj.UITable.CellEditCallback = @obj.onCellEdit;
            obj.UITable.CellSelectionCallback = @obj.onCellSelection;
            
            % Set up key press callback if provided
            if ~isempty(obj.KeyPressCallback)
                parentFig = ancestor(obj.Parent, 'figure');
                if ~isempty(parentFig)
                    set(parentFig, 'WindowKeyPressFcn', obj.KeyPressCallback);
                end
            end
            
            obj.UITable.ClickedFcn = @obj.onMouseClicked;
            obj.UITable.DoubleClickedFcn = @obj.onMouseDoubleClicked;
        end
        
        function updateTableDisplay(obj)
            %updateTableDisplay Update the table display
            
            if isempty(obj.MetaTable)
                obj.UITable.Data = [];
                obj.UITable.ColumnName = {};
                obj.UITable.ColumnFormat = {};
                obj.UITable.ColumnEditable = [];
                return
            end
            
            % Prepare data
            [data, ~, columnEditable] = obj.prepareTableData();
            columnNames = obj.getColumnDisplayNames();
            
            % Update table properties
            obj.UITable.Data = cell2table(data);
            obj.UITable.ColumnName = columnNames;
            % Commented out on purpose, not needed when data is a table
            %obj.UITable.ColumnFormat = columnFormat;
            obj.UITable.ColumnEditable = columnEditable;

            % Apply column widths from settings if available
            % if ~isempty(obj.ColumnSettings) && isfield(obj.ColumnSettings, 'ColumnWidth')
            %     obj.UITable.ColumnWidth = obj.ColumnSettings.ColumnWidth;
            % else
            %     obj.UITable.ColumnWidth = 'auto';
            % end
        end
        
        function component = getUIComponent(obj)
            %getUIComponent Get the underlying UI component
            component = obj.UITable;
        end
    end

    methods (Access = private)        
        function onCellEdit(obj, ~, event)
            %onCellEdit Callback for cell edits
            
            if isempty(event.Indices)
                return
            end
            
            rowIdx = event.Indices(1);
            colIdx = event.Indices(2);
            newValue = event.NewData;
            
            % Handle the edit
            obj.handleCellEdit(rowIdx, colIdx, newValue);
        end
        
        function onCellSelection(obj, ~, event)
            %onCellSelection Callback for selection changes
            
            if isempty(event.Indices)
                obj.handleSelectionChange([], []);
                return
            end
            
            rowIndices = unique(event.Indices(:, 1));
            colIndices = unique(event.Indices(:, 2));
            
            obj.handleSelectionChange(rowIndices, colIndices);
        end
              
        function onMouseClicked(obj, ~, ~)
            %onMouseDoubleClicked Handle double-click events
            
            % Check both property names for compatibility
            if ~isempty(obj.MouseClickedCallback)

                %obj.MouseClickedCallback(src, compEvent)
            end
        end
        
        function onMouseDoubleClicked(obj, src, event)
            %onMouseDoubleClicked Handle double-click events
            
            % Check both property names for compatibility
            if ~isempty(obj.MouseDoubleClickedFcn)
                compEvent = struct;
                compEvent.Cell = [ event.InteractionInformation.DisplayRow, ...
                    event.InteractionInformation.DisplayColumn];
                obj.MouseDoubleClickedFcn(src, compEvent)
            end
        end

        function onContextMenuOpened(obj, src, evt)
            hFigure = ancestor(src, 'figure');
            clickedRow = evt.InteractionInformation.DisplayRow;
            clickedCol = evt.InteractionInformation.DisplayColumn;

            % Get children from the unified private context menu
            if isempty(obj.PrivateTableContextMenu) || ~isvalid(obj.PrivateTableContextMenu)
                return;
            end
            children = obj.PrivateTableContextMenu.Children;

            isOutsideTable = isempty(clickedRow) && isempty(clickedCol);
            isInColumnHeader = isempty(clickedRow) && ~isempty(clickedCol);

            if isOutsideTable
                % Do nothing - all items hidden by default or keep current state
                [obj.PrivateTableContextMenu.Children.Visible] = deal('off');


            % Conditionally show/hide context menu items based on whether user
            % right clicks in the table or in the table column header
            elseif isInColumnHeader
                % Show header items, hide table items
                hide = strcmp({children.Tag}, 'table');

                [obj.PrivateTableContextMenu.Children(hide).Visible] = deal('off');
                [obj.PrivateTableContextMenu.Children(~hide).Visible] = deal('on');
            else
                % Show table items, hide header items
                hide = strcmp({children.Tag}, 'header');

                [obj.PrivateTableContextMenu.Children(hide).Visible] = deal('off');
                [obj.PrivateTableContextMenu.Children(~hide).Visible] = deal('on');
            end

            % Update selection of rows on right clicks.
            if strcmp( hFigure.SelectionType, 'extend' )
                if ~isempty( obj.UITable.Selection ) % Expand selection
                    selectionRange = [min([obj.UITable.Selection, clickedRow]), max([obj.UITable.Selection, clickedRow])];
                    obj.UITable.Selection = selectionRange(1):selectionRange(2);
                else
                    obj.UITable.Selection = evt.InteractionInformation.DisplayRow;
                end
            else
                if ismember(clickedRow, obj.UITable.Selection)
                    % pass
                else
                    obj.UITable.Selection = evt.InteractionInformation.DisplayRow;
                end
            end
        end
    end

    methods (Access = protected) % Property post set methods
        function postSetTableContextMenu(obj)
            % Rebuild the unified context menu when TableContextMenu changes
            obj.rebuildUnifiedContextMenu();
        end
        
        function postSetColumnHeaderContextMenu(obj)
            % Rebuild the unified context menu when ColumnHeaderContextMenu changes
            obj.rebuildUnifiedContextMenu();
        end
    end
    
    methods (Access = private) % Context menu management
        function rebuildUnifiedContextMenu(obj)
            %rebuildUnifiedContextMenu Create a unified context menu combining table and header menus
            %   Creates a private context menu that includes items from both
            %   TableContextMenu and ColumnHeaderContextMenu, tagging them
            %   appropriately so they can be shown/hidden based on click location.
            
            % Delete existing private context menu if it exists
            if ~isempty(obj.PrivateTableContextMenu) && isvalid(obj.PrivateTableContextMenu)
                delete(obj.PrivateTableContextMenu);
            end
            
            % Create new unified context menu
            parentFig = ancestor(obj.Parent, 'figure');
            if isempty(parentFig)
                return;
            end
            
            obj.PrivateTableContextMenu = uicontextmenu(parentFig);
            
            % Copy items from TableContextMenu and tag them as 'table'
            if ~isempty(obj.TableContextMenu) && isvalid(obj.TableContextMenu)
                tableItems = obj.TableContextMenu.Children;
                for i = numel(tableItems):-1:1  % Reverse order to maintain menu order
                    obj.copyMenuItem(tableItems(i), 'table');
                end
            end
            
            % Copy items from ColumnHeaderContextMenu and tag them as 'header'
            if ~isempty(obj.ColumnHeaderContextMenu) && isvalid(obj.ColumnHeaderContextMenu)
                headerItems = obj.ColumnHeaderContextMenu.Children;
                for i = numel(headerItems):-1:1  % Reverse order to maintain menu order
                    obj.copyMenuItem(headerItems(i), 'header');
                end
            end
            
            % Assign the unified context menu to the UITable
            obj.UITable.ContextMenu = obj.PrivateTableContextMenu;
            obj.UITable.ContextMenu.ContextMenuOpeningFcn = @obj.onContextMenuOpened;
        end
        
        function copyMenuItem(obj, sourceItem, tag)
            %copyMenuItem Copy a menu item from source to target menu with a tag
            
            % Create new menu item in target
            newItem = uimenu(obj.PrivateTableContextMenu);
            
            % Copy properties
            newItem.Text = sourceItem.Text;
            newItem.Tag = tag;
            
            % Copy callback if it exists
            if ~isempty(sourceItem.MenuSelectedFcn)
                newItem.MenuSelectedFcn = sourceItem.MenuSelectedFcn;
            end
            
            % Copy other common properties
            if isprop(sourceItem, 'Separator')
                newItem.Separator = sourceItem.Separator;
            end
            if isprop(sourceItem, 'Enable')
                newItem.Enable = sourceItem.Enable;
            end
            if isprop(sourceItem, 'Checked')
                newItem.Checked = sourceItem.Checked;
            end
            if isprop(sourceItem, 'Accelerator')
                newItem.Accelerator = sourceItem.Accelerator;
            end
        end
    end
end
