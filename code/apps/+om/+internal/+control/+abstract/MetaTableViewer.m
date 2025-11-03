classdef (Abstract) MetaTableViewer < handle & matlab.mixin.SetGet
%MetaTableViewer Abstract base class for metadata table viewing
%
%   This class defines the interface and common functionality for viewing
%   metadata tables. Concrete implementations handle UI-specific details.
%
%   Properties:
%       MetaTable - The underlying table data
%       MetaTableType - Type identifier for the table
%       MetaTableVariableAttributes - Struct with variable attributes
%
%   Methods:
%       getSelectedEntries - Get indices of selected rows
%       refreshTable - Update the table display
%       updateCells - Update specific cells
%       resetTable - Reset table to original state

% Todo: 
% - Persistent settings per table type
% - Handle cell edit
% - id column is not editable

% Some context menu items could be table generic, like delete row, hide
% column etc.

    % Public properties
    properties (SetAccess = public) % Todo: protected
        MetaTable                           % Table or nansen.metadata.MetaTable
        MetaTableVariableAttributes struct  % Variable metadata
    end
    
    properties (SetAccess = public)
        MetaTableType char = ''             % Type identifier (e.g., 'session')
    end
    
    properties (Abstract, SetAccess = protected)
        Parent                              % Parent container (figure, panel, etc.)
    end
    
    % Configuration properties
    properties
        GetTableVariableAttributesFcn = []   % Function to get variable attributes
        CellEditCallback = []                % Callback when cell is edited
        CellSelectionCallback = []           % Callback when selection changes
        MouseClickedCallback = []            % Callback for mouse clicks
        MouseDoubleClickedFcn = []           % Alias for MouseClickedCallback (for NANSEN compatibility)
        KeyPressCallback = []                % Callback for key presses
        TableContextMenu
        ColumnHeaderContextMenu % Not implemented yet
    end
    
    % UI State
    properties (SetAccess = public)
        ColumnSettings struct                % Settings for columns (width, order, etc.)
        SelectedRows double = []             % Currently selected row indices
        SelectedColumns double = []          % Currently selected column indices
    end
    
    % Events
    events
        SelectionChanged                     % Fired when selection changes
        DataChanged                          % Fired when data is edited
        ColumnOrderChanged                   % Fired when columns are reordered
    end
    
    % Abstract methods - must be implemented by subclasses
    methods (Abstract, Access = public)
        % Create or recreate the table UI component
        createTableComponent(obj)
        
        % Update the table display without recreating
        updateTableDisplay(obj)
        
        % Get the actual UI component (for embedding in layouts)
        component = getUIComponent(obj)
    end
    
    % Concrete public methods
    methods (Access = public)
        function rowIndices = getSelectedEntries(obj)
            %getSelectedEntries Get indices of selected rows
            %
            %   Returns row indices in the original (unfiltered) data
            rowIndices = obj.SelectedRows;
        end
        
        function columnNames = getColumnNames(obj, columnIndices)
            %getColumnNames Get current column names
            if nargin < 2; columnIndices = []; end

            if isempty(obj.MetaTable)
                columnNames = {};
            else
                columnNames = obj.MetaTable.Properties.VariableNames;
                if ~isempty(columnIndices)
                    columnNames = columnNames(columnIndices);
                end
                if numel(columnNames) == 1 && iscell(columnNames)
                    columnNames = columnNames{1};
                end
            end
        end
        
        function updateCells(obj, rowIndices, columnIndices, newValues)
            %updateCells Update specific cells in the table
            %
            %   updateCells(obj, rowIndices, columnIndices, newValues)
            %   updates the specified cells with new values
            
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
            notify(obj, 'DataChanged', matlab.event.EventData);
        end
        
        function refreshTable(obj, newMetaTable)
            %refreshTable Refresh table with new or updated data
            %
            %   refreshTable(obj) refreshes with current MetaTable
            %   refreshTable(obj, newMetaTable) sets new data and refreshes
            
            if nargin > 1
                obj.setMetaTable(newMetaTable);
            end
            
            obj.updateTableDisplay();
        end
        
        function resetTable(obj)
            %resetTable Reset table to initial state
            obj.SelectedRows = [];
            obj.SelectedColumns = [];
            obj.MetaTable = table.empty;
            obj.updateTableDisplay();
        end
        
        function delete(obj)
            %delete Cleanup when object is destroyed
            if ~isempty(obj.TableContextMenu) && isvalid(obj.TableContextMenu)
                delete(obj.TableContextMenu);
            end
            if ~isempty(obj.ColumnHeaderContextMenu) && isvalid(obj.ColumnHeaderContextMenu)
                delete(obj.ColumnHeaderContextMenu);
            end
        end
    end
    
    % Set/Get methods
    methods
        function set.MetaTableType(obj, newValue)
            %set.MetaTableType Setter for MetaTableType property
            %   Updates variable attributes when type changes
            
            % Convert to char and lowercase for consistency
            if isstring(newValue)
                newValue = char(newValue);
            end
            
            % Store the value
            obj.MetaTableType = lower(newValue);
            
            % Update variable attributes
            %obj.updateMetaTableVariableAttributes();
        end
    
        function set.TableContextMenu(obj, value)
            obj.TableContextMenu = value;
            obj.postSetTableContextMenu()
        end

        function set.ColumnHeaderContextMenu(obj, value)
            obj.ColumnHeaderContextMenu = value;
            obj.postSetColumnHeaderContextMenu()
        end
    end
    
    % Protected methods - can be used/overridden by subclasses
    methods (Access = protected)
        function updateMetaTableVariableAttributes(obj)
            %updateMetaTableVariableAttributes Update variable attributes
            %   Called when MetaTable or MetaTableType changes
            
            % Only update if we have both a table and a type
            if isempty(obj.MetaTable) || isempty(obj.MetaTableType)
                return
            end
            
            if ~isempty(obj.GetTableVariableAttributesFcn)
                obj.MetaTableVariableAttributes = ...
                    obj.GetTableVariableAttributesFcn(obj.MetaTableType);
            else
                obj.MetaTableVariableAttributes = ...
                    obj.createDefaultVariableAttributes();
            end
        end
        
        function setMetaTable(obj, metaTable)
            %setMetaTable Set the meta table and update attributes
            %   This is a protected method for internal use
            
            % Validate input
            obj.validateMetaTable(metaTable);
            
            % Store the table
            if isa(metaTable, 'table')
                obj.MetaTable = metaTable;
            elseif isa(metaTable, 'nansen.metadata.MetaTable')
                obj.MetaTable = metaTable.entries;
            end

            % Update variable attributes
            obj.updateMetaTableVariableAttributes();
        end
        
        function validateMetaTable(~, metaTable)
            %validateMetaTable Validate that input is a valid table
            if ~istable(metaTable) && ...
               ~isa(metaTable, 'nansen.metadata.MetaTable')
                error('MetaTableViewer:InvalidInput', ...
                    'Input must be a table or nansen.metadata.MetaTable');
            end
        end
        
        function attributes = createDefaultVariableAttributes(obj)
            %createDefaultVariableAttributes Create default attributes
            %
            %   Creates basic attributes for all variables in the table
            
            if isempty(obj.MetaTable)
                attributes = struct([]);
                return
            end
            
            varNames = obj.MetaTable.Properties.VariableNames;
            numVars = numel(varNames);
            
            % Initialize struct array
            attributes = struct(...
                'Name', varNames, ...
                'DisplayName', varNames, ...
                'IsEditable', num2cell(false(1, numVars)), ...
                'Visible', num2cell(true(1, numVars)), ...
                'Width', num2cell(repmat(100, 1, numVars)), ...
                'HasOptions', num2cell(false(1, numVars)), ...
                'TableType', repmat({obj.MetaTableType}, 1, numVars));
        end
        
        function [data, columnFormat, columnEditable] = prepareTableData(obj)
            %prepareTableData Prepare data for display in UI table
            %
            %   Converts the MetaTable to cell array format suitable for
            %   uitable and determines column formats
            
            if isempty(obj.MetaTable)
                data = [];
                columnFormat = {};
                columnEditable = [];
                return
            end
            
            % Convert to cell array
            data = table2cell(obj.MetaTable);
            
            % Determine column formats
            varNames = obj.MetaTable.Properties.VariableNames;
            numCols = numel(varNames);
            columnFormat = cell(1, numCols);
            columnEditable = false(1, numCols);

            numRows = height(obj.MetaTable);
            
            for i = 1:numCols
                % Get variable class
                varClass = class(obj.MetaTable.(varNames{i}));
                
                % Determine format
                switch varClass
                    case {'double', 'single', 'int8', 'int16', 'int32', 'int64', ...
                          'uint8', 'uint16', 'uint32', 'uint64'}
                        columnFormat{i} = 'numeric';
                    case 'logical'
                        columnFormat{i} = 'logical';
                    case {'datetime', 'string'}
                        columnFormat{i} = 'char';
                        % Convert datetime to char for display
                        columnData = cellstr(obj.MetaTable.(varNames{i}));
                        if isempty(columnData)
                            data(:, i) = repmat({''}, numRows, 1);
                        else
                            data(:, i) = columnData;
                        end
                    case 'categorical'
                        columnFormat{i} = categories(obj.MetaTable.(varNames{i}));
                        columnFormat{i} = reshape(columnFormat{i}, 1, []);
                    % case 'string'
                    %     columnFormat{i} = 'char';
                    %     data(:, i) = cellstr(obj.MetaTable.(varNames{i}));
                    otherwise
                        columnFormat{i} = 'char';
                        % Try to convert to string
                        try
                            data(:, i) = cellstr(string(obj.MetaTable.(varNames{i})));
                        catch
                            data(:, i) = repmat({''}, size(data, 1), 1);
                        end
                end
                
                % Check if editable from attributes
                if ~isempty(obj.MetaTableVariableAttributes)
                    idx = strcmp({obj.MetaTableVariableAttributes.Name}, varNames{i});
                    if any(idx)
                        columnEditable(i) = obj.MetaTableVariableAttributes(idx).IsEditable;
                    end
                end
            end
        end
        
        function columnNames = getColumnDisplayNames(obj)
            %getColumnDisplayNames Get display names for columns
            
            varNames = obj.getColumnNames();
            columnNames = varNames;
            
            if ~isempty(obj.MetaTableVariableAttributes)
                for i = 1:numel(varNames)
                    idx = strcmp({obj.MetaTableVariableAttributes.Name}, varNames{i});
                    if any(idx)
                        % Use DisplayName if available, otherwise use Name
                        if isfield(obj.MetaTableVariableAttributes, 'DisplayName') && ...
                           ~isempty(obj.MetaTableVariableAttributes(idx).DisplayName)
                            columnNames{i} = obj.MetaTableVariableAttributes(idx).DisplayName;
                        end
                    end
                end
            end
        end
        
        function handleCellEdit(obj, rowIdx, colIdx, newValue)
            %handleCellEdit Internal handler for cell edits
            
            % Update the underlying data
            obj.updateCells(rowIdx, colIdx, {newValue});
            
            % Call user callback if provided
            if ~isempty(obj.CellEditCallback)
                evtData = struct(...
                    'Indices', [rowIdx, colIdx], ...
                    'NewValue', newValue, ...
                    'PreviousValue', obj.MetaTable{rowIdx, colIdx});
                obj.CellEditCallback(obj, evtData);
            end
        end
        
        function handleSelectionChange(obj, rowIndices, colIndices)
            %handleSelectionChange Internal handler for selection changes
            
            obj.SelectedRows = rowIndices;
            obj.SelectedColumns = colIndices;
            
            % Notify listeners
            notify(obj, 'SelectionChanged');
            
            % Call user callback if provided
            if ~isempty(obj.CellSelectionCallback)
                evtData = struct('Indices', [rowIndices(:), colIndices(:)]);
                obj.CellSelectionCallback(obj, evtData);
            end
        end
    end

    methods (Abstract, Access = protected) % Property post set methods
        postSetTableContextMenu(obj)
        postSetColumnHeaderContextMenu(obj)
    end
end
