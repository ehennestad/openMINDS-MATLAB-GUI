classdef MetadataEditor < handle
%     
%   TODO:
%       [x] Save figure size to app settings
%       [x] Save metadata set
%       [ ] Sidebar should be populated with collection types, or top 10 collection types....?
%       [ ] Fill out all linked types which are not controlled terms with
%           categoricals where each value is a id/label for one of the linked
%           types...
%       [ ] Add label for required properties in table columns and editor...
%       [ ] Check out BCCN
%       [ ] Move +category to +openminds
%       [ ] Fix broken controlled terms
%       [ ] Add way to have array of linked types on property
%       [ ] Add incoming links for schemas
%       [ ] Get label/id as method on Schema class
%       [ ] In table view, show connected nodes, in graph view, show all
%           available, or show predefined templates...
%       [ ] Dynamic listbox on left side panel
%
%       [ ] Treat embedded types and linked types differently. Embedded
%           types are not added to the set, but only added to schema 
%           instances. Should embedded types be value classes.
%
%       [ ] Linked types are just links...


% ABBREVIATIONS:
%       
%       OM : openMinds
%

    properties
        MetadataInstance
        MetadataCollection openminds.Collection
        MetadataSet
    end

    properties (Constant)
        Pages = {'Table Viewer', 'Graph Viewer', 'Timeline Viewer'} %, 'Figures'}
    end

    properties (SetAccess = private)
        CurrentSchemaTableName char
    end

    properties (Access = public) % UI Components
        Figure
    end

    properties (Access = private) % UI Components
        UIPanel
        UIContainer
        UIMetaTableViewer
        UISideBar
        UIGraphViewer
        UIButtonCreateNew
    end

    properties (Access = private)
        SchemaMenu
    end

    properties (Access = private)
        CurrentTableInstanceIds
    end

    properties (Access = private, Dependent)
        SaveFolder
    end

    properties (Constant)
        METADATA_COLLECTION_FILENAME = 'metadata_collection.mat'
    end
    
% Create figure

    methods

        function obj = MetadataEditor(metadataCollection)

            if nargin < 1            
                obj.loadMetadataCollection()
            else
                if isa(metadataCollection, 'openminds.Collection')
                    metadataCollection = om.ui.UICollection.fromCollection(metadataCollection);
                end
                obj.MetadataCollection = metadataCollection;
                %obj.MetadataCollection.createListenersForAllInstances()
            end

            obj.createFigure()
            obj.createPanels()

            obj.updateLayoutPositions()

            obj.createTabGroup()
            obj.createCreateNewButton()

            typeSelections = obj.loadTypeQuickSelection();
            obj.createSchemaSelectorSidebar(typeSelections)
            obj.plotOpenMindsLogo()

            hAxes = axes(obj.UIContainer.UITab(2));
            hAxes.Position = [0,0,0.999,1];

            if false %obj.showMetadataModuleGraph
                % % Create graph of the core module of openMINDS
                [G,e] = om.internal.graph.generateGraph('core');
            else
                G = obj.MetadataCollection.graph;
                e = "not implemented";
            end
            obj.addMetadataCollectionListeners()

            h = om.internal.graphics.InteractiveOpenMINDSPlot(G, hAxes, e);
            obj.UIGraphViewer = h;

            % NB NB NB: Some weird bug occurs if this is created before the
            % axes with the graph plot, where the axes current point seems
            % to be reversed in the y-dimension.
            obj.initializeTableViewer()

            obj.initializeTableContextMenu()

            obj.createMainMenu()

            % Add these callbacks after every component is made
            obj.Figure.SizeChangedFcn = @(s, e) obj.onFigureSizeChanged;
            obj.Figure.CloseRequestFcn = @obj.onExit;

            obj.changeSelection('DatasetVersion')
                       
            obj.configureFigureInteractionCallbacks()
            
            if ~nargout
                clear obj
            end
        end

        function delete(obj)
            % Save column view settings to project
            obj.saveMetatableColumnSettings()
            obj.saveTypeQuickSelection()
            
%             if isempty(app.MetaTable)
%                 return
%             end
            
            isdeletable = @(x) ~isempty(x) && isvalid(x);
            
            if isdeletable(obj.UIMetaTableViewer)
                delete(obj.UIMetaTableViewer)
            end

            delete(obj.MetadataCollection)
            delete(obj.UIGraphViewer)
            delete(obj.UIMetaTableViewer)

            delete(obj.Figure)
        end

        function onExit(obj, ~, ~)
            obj.saveMetadataCollection()
            obj.saveGraphCoordinates() % Todo

            windowPosition = obj.Figure.Position;
            setpref('openMINDS', 'WindowSize', windowPosition)

            delete(obj)
        end

    end

    methods %Set / get 
        function saveFolder = get.SaveFolder(~)
            % Todo: Get from preferences
            saveFolder = fullfile(userpath, 'openMINDS-MATLAB-UI', 'userdata');
            if ~isfolder(saveFolder); mkdir(saveFolder); end
        end
    end

    methods

        function changeSelection(obj, schemaName)
            if ~any(strcmp(obj.UISideBar.Items, schemaName))
                % Todo: Update sidebar control to have settable items
                items = obj.UISideBar.Items;
                delete(obj.UISideBar);
                newItems = [items, {schemaName}];
                obj.createSchemaSelectorSidebar(newItems)
            end
            
            obj.UISideBar.SelectedItems = schemaName;
        end
        
        function updateLayoutPositions(obj)
            
            figPosPix = getpixelposition(obj.Figure);
            W = figPosPix(3);
            H = figPosPix(4);

            MARGIN = 10;
            PADDING = 10;

            toolH = 30;
            logoW = 150;
            logoH = round( logoW / 2 );

            obj.UIPanel.Toolbar.Position = [MARGIN,H-MARGIN-toolH,W-MARGIN*2,toolH];
            
            h = H-MARGIN*2-toolH-PADDING;
            w = 150;

            newButtonHeight = 30;
            obj.UIPanel.SidebarL.Position = [MARGIN, MARGIN+PADDING+logoH,logoW,h-logoH-newButtonHeight-PADDING*2];
            obj.UIPanel.CreateNew.Position = [MARGIN, sum(obj.UIPanel.SidebarL.Position([2,4]))+PADDING,logoW,newButtonHeight];

            obj.UIPanel.Table.Position = [w+MARGIN+PADDING, MARGIN, W-MARGIN*2-w-PADDING, h];

            obj.UIPanel.Logo.Position = [MARGIN, MARGIN, logoW, logoH];
        end

        function saveMetatableColumnSettings(obj)
            if isempty(obj.UIMetaTableViewer); return; end
            columnSettings = obj.UIMetaTableViewer.ColumnSettings;

            rootDir = fileparts(mfilename('fullpath'));
            filename = fullfile(rootDir, 'table_column_settings.mat');

            save(filename, 'columnSettings');
        end

        function typeSelections = loadTypeQuickSelection(obj)
            rootDir = fileparts(mfilename('fullpath'));
            filename = fullfile(rootDir, 'type_selection.mat');
            
            if isfile(filename)
                S = load(filename, 'typeSelections');
                typeSelections = S.typeSelections;
            else
                typeSelections = "";
            end
        end

        function saveTypeQuickSelection(obj)
            rootDir = fileparts(mfilename('fullpath'));
            filename = fullfile(rootDir, 'type_selection.mat');
            
            typeSelections = obj.UISideBar.Items;
            save(filename, 'typeSelections');
        end
    end

    methods (Access = private) % Internal utility methods
        function exportToWorkspace(obj)
            schemaName = obj.CurrentSchemaTableName;
            idx = obj.UIMetaTableViewer.getSelectedEntries();
            schemaInstance = obj.MetadataCollection.getSchemaInstanceByIndex(schemaName, idx);
            
            varName = matlab.lang.makeValidName( schemaInstance.DisplayString );
            assignin('base', varName, schemaInstance)
        end
    end

    methods (Access = private) % App initialization and update methods
        
        function windowPosition = getWindowPosition(~)
            if ispref('openMINDS', 'WindowSize')
                windowPosition = getpref('openMINDS', 'WindowSize');
            else
                windowPosition = [100, 100, 1000, 600];
            end
        end

        function createFigure(obj)
            windowPosition = obj.getWindowPosition();
            obj.Figure = figure('Position', windowPosition);
            obj.Figure.Name = 'openMINDS';
            obj.Figure.NumberTitle = 'off';
            obj.Figure.MenuBar = 'none';
            obj.Figure.ToolBar = 'none';
        end

        function createPanels(obj)
            obj.UIPanel.Toolbar = uipanel(obj.Figure);
            obj.UIPanel.CreateNew = uipanel(obj.Figure);
            obj.UIPanel.SidebarL = uipanel(obj.Figure);
            obj.UIPanel.Table = uipanel(obj.Figure);
            obj.UIPanel.Logo = uipanel(obj.Figure);
            
            panels = struct2cell(obj.UIPanel);
            set([panels{:}], 'Units', 'pixels', 'BackgroundColor', 'w', 'BorderType','etchedin')
        end

        function createTabGroup(obj)
        %createTabGroup Create the tabgroup container and add tabs

            obj.UIContainer.TabGroup = uitabgroup(obj.UIPanel.Table);
            obj.UIContainer.TabGroup.Units = 'normalized';

            obj.UIContainer.UITab = gobjects(0);

            for i = 1:numel(obj.Pages)
                pageName = obj.Pages{i};
                
                hTab = uitab(obj.UIContainer.TabGroup);
                hTab.Title = pageName;

                obj.UIContainer.UITab(i) = hTab;
            end
        end

        function createMainMenu(obj)
            
            m = uimenu(obj.Figure, 'Text', 'openMINDS GUIDE');
            mItem = uimenu(m, 'Text', 'Select project type');
            L = recursiveDir( fullfile(om.internal.rootpath, 'config', 'template_projects'), 'Type','folder');
            for i = 1:numel(L)
                mSubItem = uimenu(mItem, "Text", L(i).name);
                mSubItem.Callback = @obj.onProjectTypeSelected;
            end
                       
            mItem = uimenu(m, 'Text', 'Select graph plot layout');
            layoutOptions = ["circle", "force", "layered", "subspace", "force3", "subspace3"];
            for i = 1:numel(layoutOptions)
                mSubItem = uimenu(mItem, "Text", layoutOptions(i));
                mSubItem.Callback = @obj.onGraphLayoutChanged;
            end

            % Create a separator
            m = uimenu(obj.Figure, 'Text', '|', 'Enable', 'off');

            % Todo: Get model version from preferences...
            modelRoot = fullfile(openminds.internal.rootpath, 'types', 'latest', '+openminds');
            ignoreList = {'+controlledterms'};
            
            omModels = recursiveDir(modelRoot, "Type", "folder", "IgnoreList", ignoreList, ...
                "RecursionDepth", 1, "OutputType", "FilePath");

            obj.SchemaMenu = om.SchemaMenu(obj, omModels, true);
            obj.SchemaMenu.MenuSelectedFcn = @obj.onSchemaMenuItemSelected;
        end

        function createCreateNewButton(obj)
            
            obj.UIButtonCreateNew = uicontrol(obj.UIPanel.CreateNew, 'Style', 'pushbutton');
            obj.UIButtonCreateNew.String = "Create New";
            obj.UIButtonCreateNew.Callback = @obj.onCreateNewButtonPressed;
            obj.UIButtonCreateNew.Units = 'normalized';
            obj.UIButtonCreateNew.Position = [0,0,1,1];
            obj.UIButtonCreateNew.FontWeight = 'bold';
            obj.UIButtonCreateNew.FontSize = 14;

            %obj.UIButtonCreateNew.BackgroundColor = [0,231,102]/255;
            obj.UIPanel.CreateNew.BorderType = 'none';
            obj.UIPanel.CreateNew.BackgroundColor = obj.Figure.Color;
        end
        
        function createSchemaSelectorSidebar(obj, schemaTypes)
        %createSchemaSelectorSidebar Create a selector widget in side panel

            if nargin < 2 || (isstring(schemaTypes) && schemaTypes=="")
                schemaTypes = {'DatasetVersion'};
            end
                        
            sideBar = om.gui.control.ListBox(obj.UIPanel.SidebarL, schemaTypes);
            sideBar.SelectionChangedFcn = @obj.onSelectionChanged;
            obj.UISideBar = sideBar;
        end
        
        function initializeTableViewer(obj)

            columnSettings = obj.loadMetatableColumnSettings();
            nvPairs = {'ColumnSettings', columnSettings, 'TableFontSize', 8};
            
            % Need to ensure a nansen user session is active before
            % creating meta table viewer. Todo: Should not be necessary
            nansen.internal.user.NansenUserSession.instance();
            
            h = nansen.MetaTableViewer( obj.UIContainer.UITab(1), [], nvPairs{:});
            h.HTable.KeyPressFcn = @obj.onKeyPressed;
            obj.UIMetaTableViewer = h;

            colSettings = h.ColumnSettings;
            [colSettings(:).IsEditable] = deal(true);
            h.ColumnSettings = colSettings;
            %obj.UIMetaTableViewer.HTable.Units

            h.CellEditCallback = @obj.onMetaTableDataChanged;
            h.GetTableVariableAttributesFcn = @obj.createTableVariableAttributes;
            h.MouseDoubleClickedFcn = @obj.onMouseDoubleClickedInTable;
        end

        function initializeTableContextMenu(obj)
            [menuInstance, graphicsMenu] = om.TableContextMenu(obj.Figure);
            obj.UIMetaTableViewer.TableContextMenu = graphicsMenu;
            menuInstance.DeleteItemFcn = @obj.onDeleteMetadataInstanceClicked;
        end

        function plotOpenMindsLogo(obj)
        %plotLogo Plot openMINDS logo in the logo panel   
            
            % Load the logo from file
            logoFilename = 'light_openMINDS-logo.png';
            logoFilename = om.MetadataEditor.getLogoFilepath();

            if ~exist(logoFilename, 'file')
                fprintf('Downloading openMINDS logo...'); fprintf(newline)
                obj.downloadOpenMindsLogo()
                fprintf('Download finished'); fprintf(newline)
            end

            [C, ~, A] = imread(logoFilename);

            % Create axes for plotting logo
            ax = axes(obj.UIPanel.Logo, 'Position', [0,0,1,1]);

            % Plot logo as image
            hImage = image(ax, 'CData', C);
            hImage.AlphaData = A;

            % Customize axes
            ax.Color = 'white';
            ax.YDir = 'reverse';
            ax.Visible = 'off';
        end

        function configureFigureInteractionCallbacks(obj)
            
            %obj.Figure.WindowButtonDownFcn = @obj.onMousePressed;
            %obj.Figure.WindowButtonMotionFcn = @obj.onMouseMotion;
            obj.Figure.WindowKeyPressFcn = @obj.onKeyPressed;
            %obj.Figure.WindowKeyReleaseFcn = @obj.onKeyReleased;
            
            %[~, hJ] = evalc('findjobj(obj.Figure)');
            %hJ(2).KeyPressedCallback = @obj.onKeyPressed;
            %hJ(2).KeyReleasedCallback = @obj.onKeyReleased;
            
        end

    end

    methods (Access = private) % Metadata Collection configuration methods

        function addMetadataCollectionListeners(obj)

            addlistener(obj.MetadataCollection, 'CollectionChanged', @obj.onMetadataCollectionChanged);
            addlistener(obj.MetadataCollection, 'InstanceModified', @obj.onMetadataInstanceModified);

        end

        function filepath = getMetadataCollectionFilepath(obj)
            filepath = fullfile(obj.SaveFolder, obj.METADATA_COLLECTION_FILENAME);
        end
        
        function saveMetadataCollection(obj)
            metadataFilepath = obj.getMetadataCollectionFilepath();
            
            % Todo: Serialize
            %S = struct;

            MetadataCollection = obj.MetadataCollection; %#ok<PROP> 
            save(metadataFilepath, 'MetadataCollection')
            % Todo: Are listeners saved???
        end

        function loadMetadataCollection(obj)
            metadataFilepath = obj.getMetadataCollectionFilepath();
            if isfile(metadataFilepath)
                S = load(metadataFilepath, 'MetadataCollection');
                obj.MetadataCollection = S.MetadataCollection;
                %obj.MetadataCollection.createListenersForAllInstances()
            else
                obj.MetadataCollection = om.ui.UICollection();
            end


% % %             % Reattach listeners
% % %             addlistener(obj.MetadataCollection, 'CollectionChanged', ...
% % %                 @obj.onMetadataCollectionChanged)

        end

        function saveGraphCoordinates(obj)
            % Todo.
        end

    end

    methods (Access = private) % Internal callback methods
        
        function onKeyPressed(obj, ~, evt)

            switch evt.Key
                case 'x'
                    obj.exportToWorkspace()
            end

        end

        function onMetaTableDataChanged(obj, ~, evt)
        % onMetaTableDataChanged - Call back to handle value changes from table
            instanceIndex = evt.Indices(1);
            instanceID = obj.CurrentTableInstanceIds{instanceIndex};

            % Todo: Handle actions...
            % Update: obj.MetaTableVariableAttributes
            % Update column layout.

            % Todo: Update column format for individual column
            
            % NB: Indices are for the table model
            propName = obj.UIMetaTableViewer.MetaTable.Properties.VariableNames{evt.Indices(2)};

            propValue = evt.NewValue;
            obj.MetadataCollection.modifyInstance(instanceID, propName, propValue);
        end

        function onSelectionChanged(obj, ~, evt)
            
            selectedTypes = evt.NewSelection;
            obj.CurrentSchemaTableName = selectedTypes;

            % check if schema has a table
            if numel(selectedTypes) == 1
                schemaType = openminds.internal.vocab.getSchemaName(selectedTypes{1});
                [metaTable, ids] = obj.MetadataCollection.getTable(schemaType);
                obj.CurrentTableInstanceIds = ids;
            else
                metaTable = obj.MetadataCollection.joinTables(selectedTypes);
            end
            obj.updateUITable(metaTable)
            obj.UIMetaTableViewer.MetaTableType = string(schemaType);
        end

        function onFigureSizeChanged(app)
            app.updateLayoutPositions()
        end

        function onProjectTypeSelected(obj, src, ~)

            delete(obj.SchemaMenu)

            config = jsondecode( fileread( fullfile(om.internal.rootpath, 'config', 'template_projects', src.Text, 'project_config.json')) );
            models = config.properties.models;
            if strcmp(models, "all")
                expression = '';
            else
                expression = strjoin(models, '|');
            end
            ignoreList = {'+controlledterms'};

            modelRoot = fullfile(openminds.internal.rootpath, 'types', 'latest', '+openminds');
            omModels = recursiveDir(modelRoot, "Type", "folder", ...
                "Expression", expression, ...
                "IgnoreList", ignoreList, ...
                "RecursionDepth", 1, "OutputType", "FilePath");

            obj.Figure.CurrentObject = obj.UIButtonCreateNew;

            obj.SchemaMenu = om.SchemaMenu(obj, omModels, true);
            obj.SchemaMenu.MenuSelectedFcn = @obj.onSchemaMenuItemSelected;
        end

        function onGraphLayoutChanged(obj, src, ~)
            set([src.Parent.Children], 'Checked', 'off')
            src.Checked = 'on';
            obj.UIGraphViewer.Layout = src.Text;
        end

        function onSchemaMenuItemSelected(obj, functionName, selectionMode)
        % onSchemaMenuItemSelected - Instance menu selection callback

            % Simplify function name. In order to make gui menus more
            % userfriendly, the alias version of the schemas are used.
            functionNameSplit = strsplit(functionName, '.');
            if numel(functionNameSplit)==4
                %functionName = strjoin(functionNameSplit([1,2,4]), '.');
            end

            switch selectionMode
                case 'Single'
                    n = 1;
                case 'Multiple'
                    n = inputdlg('Enter number of items to create:');
                    if n{1}==0; return; end
                    n = str2double(n{1});
                case 'Help'
                    help(functionName)
                    return
                case 'Open'
                    open(functionName)
                case 'View'
                    schemaType = functionNameSplit{end};
                    %obj.UISideBar.Items = schemaType;
                    obj.changeSelection(schemaType)
                    return
            end

            obj.MetadataCollection.disableEvent('CollectionChanged')
            om.uiCreateNewInstance(functionName, obj.MetadataCollection, "NumInstances", n)
            obj.MetadataCollection.enableEvent('CollectionChanged')
            obj.MetadataCollection.notify('CollectionChanged', event.EventData)

            className = functionNameSplit{end};
            obj.changeSelection(className)

            % Todo: update tables...!
        end

        function onCreateNewButtonPressed(obj, ~, ~)

            selectedItems = obj.UISideBar.SelectedItems{1};
            type = openminds.internal.vocab.getSchemaName(selectedItems);

            type = eval( sprintf( 'openminds.enum.Types.%s', type) );
            om.uiCreateNewInstance(type.ClassName, obj.MetadataCollection, "NumInstances", 1)

            % Todo: update tables...!
            %obj.changeSelection(string(type))
        end
        
        function onMetadataCollectionChanged(obj, ~, ~)
            
            G = obj.MetadataCollection.graph;
            obj.UIGraphViewer.updateGraph(G);
            
            [T, ids] = obj.MetadataCollection.getTable(obj.CurrentSchemaTableName);
            obj.CurrentTableInstanceIds = ids;
            obj.updateUITable(T)
        end

        function onMetadataInstanceModified(obj, ~, ~)

            G = obj.MetadataCollection.graph;
            obj.UIGraphViewer.updateGraph(G);

            T = obj.MetadataCollection.getTable(obj.CurrentSchemaTableName);
            obj.updateUITable(T)
        end

        function onDeleteMetadataInstanceClicked(obj, ~, ~)
            selectedIdx = obj.UIMetaTableViewer.getSelectedEntries();

            % Todo: Make sure this is name and not label.
            type = obj.CurrentSchemaTableName;
             
            % Todo: Support removing multiple instances.
            instanceID = obj.CurrentTableInstanceIds(selectedIdx);
            for i = 1:numel(instanceID)
                obj.MetadataCollection.remove(instanceID{i})
            end

            %obj.MetadataCollection.removeInstance(type, selectedIdx)

            [T, ids] = obj.MetadataCollection.getTable(obj.CurrentSchemaTableName);
            obj.updateUITable(T)
            obj.CurrentTableInstanceIds = ids;
            %app.MetaTable.removeEntries(selectedEntries)
            %app.UiMetaTableViewer.refreshTable(app.MetaTable)
        end
    
        function onMouseDoubleClickedInTable(obj, ~, evt)
        % onMouseDoubleClickedInTable - Callback for double clicks
        %
        %   Check if the currently selected column has an associated table
        %   variable definition with a double click callback function.

            thisRow = evt.Cell(1); % Clicked row index
            thisCol = evt.Cell(2); % Clicked column index
            
            if thisRow == 0 || thisCol == 0
                return
            end

            % Get name of column which was clicked
            thisColumnName = obj.UIMetaTableViewer.getColumnNames(thisCol);

            % Use table variable attributes to check if a double click 
            % callback function exists for the current table column
            TVA = obj.UIMetaTableViewer.MetaTableVariableAttributes([obj.UIMetaTableViewer.MetaTableVariableAttributes.HasDoubleClickFunction]);
            
            isMatch = strcmp(thisColumnName, {TVA.Name});

            if any( isMatch )
                if isa(TVA(isMatch).DoubleClickFunctionName, 'function_handle')
                    fcnHandle = TVA(isMatch).DoubleClickFunctionName;

                    instanceID = obj.CurrentTableInstanceIds{thisRow};
                    instance = obj.MetadataCollection.get(instanceID);
                    thisValue = instance.(thisColumnName);

                    [items, itemsData] = fcnHandle(thisValue);
                    if ~isempty(itemsData)
                        if iscell(itemsData); itemsData = [itemsData{:}]; end
                        instance.(thisColumnName) = itemsData;
                        newValueStr = strjoin(items, '; ');
                           
                        % TODO: Method of metatable viewer:
                        %thisColIdxView = find(strcmp(obj.UIMetaTableViewer.getColumnNames, thisColumnName));
                        thisColIdxView = find(strcmp(obj.UIMetaTableViewer.MetaTable.Properties.VariableNames, thisColumnName));

                        obj.UIMetaTableViewer.updateCells(thisRow, thisColIdxView, {newValueStr})
                    end
                    %keyboard

                else
                    error('Not supported')
                end
            else
                evt.HitObject.ColumnEditable(thisCol)=true;
                evt.HitObject.JTable.editCellAt(thisRow-1, thisCol-1);
            end
        end
    
    end

    methods (Access = private) % Internal updating

        function updateUITable(obj, metaTable)

            if ~isempty(metaTable)
                %obj.UIMetaTableViewer.resetTable()
                obj.UIMetaTableViewer.refreshTable(metaTable, true)
            else
                obj.UIMetaTableViewer.resetTable()
                obj.UIMetaTableViewer.refreshTable(table.empty, true)
            end
        end
        
        function tableVariableAttributes = createTableVariableAttributes(obj, metaTableType)

            import nansen.metadata.abstract.TableVariable;
            
            metaTable = obj.UIMetaTableViewer.MetaTable;
            if ~isempty(metaTable)

                varNames = metaTable.Properties.VariableNames;
                numVars = numel(varNames);
                S = TableVariable.getDefaultTableVariableAttribute();
                S = repmat(S, 1, numVars);
                
                % Fill out names and table type
                [S(1:numVars).Name] = varNames{:};
                [S(1:numVars).TableType] = deal(string(metaTableType));
                [S(1:numVars).IsEditable] = deal( false );

                openMindsType = openminds.enum.Types(metaTableType);
                instance = feval(openMindsType.ClassName);  
                    

                metaSchema = openminds.internal.meta.Type( instance );


                for i = 1:numel(varNames)
                    if openminds.utility.isInstance( instance.(varNames{i}) ) && ...
                            ~isa(instance.(varNames{i}), 'openminds.abstract.ControlledTerm')

                        if metaSchema.isPropertyValueScalar(varNames{i})
                            S(i).HasOptions = true;
                            S(i).OptionsList = {{'<Select>', '<Create>', '<Download>'}}; % Todo
                        else
                            propertyTypeName = instance.X_TYPE + "/" + varNames{i};
    
                            S(i).IsEditable = false;
                            S(i).HasDoubleClickFunction = true;
                            S(i).DoubleClickFunctionName = @(value, varargin) ...
                                om.uiEditHeterogeneousList(value, propertyTypeName, obj.MetadataCollection );
                        end
                    elseif openminds.utility.isMixedInstance( instance.(varNames{i}) )

                        propertyTypeName = instance.X_TYPE + "/" + varNames{i};

                        S(i).IsEditable = false;
                        S(i).HasDoubleClickFunction = true;
                        S(i).DoubleClickFunctionName = @(value, varargin) ...
                            om.uiEditHeterogeneousList(value, propertyTypeName, obj.MetadataCollection );

                        % continue
                    end
                end

                tableVariableAttributes = S;
            else
                tableVariableAttributes = TableVariable.getDefaultTableVariableAttribute();
            end
        end
    end

    methods (Static)
        function deleteMetadataCollection()
            saveFolder = fullfile(userpath, 'openMINDS', 'userdata');
            metadataFilepath = fullfile(saveFolder, om.MetadataEditor.METADATA_COLLECTION_FILENAME);
            
            if isfile(metadataFilepath)
                delete(metadataFilepath)
            end
        end
    
        function tf = isSchemaInstanceUnavailable(value)
            tf = ~isempty(regexp(value, 'No \w* available', 'once'));
        end

        function [CData, AlphaData] = loadOpenMindsLogo()
            
            % Load the logo from file
            logoFilename = om.MetadataEditor.getLogoFilepath();
            
            if ~exist(logoFilename, 'file')
                fprintf('Downloading openMINDS logo...'); fprintf(newline)
                obj.downloadOpenMindsLogo()
                fprintf('Download finished'); fprintf(newline)
            end

            [CData, ~, AlphaData] = imread(logoFilename);
        end

        function downloadOpenMindsLogo()
            logoUrl = om.common.constant.OpenMindsLogoLightURL;
            websave(om.MetadataEditor.getLogoFilepath(), logoUrl);
        end

        function logoFilepath = getLogoFilepath()
            logoUrl = om.common.constant.OpenMindsLogoLightURL;
            logoURI = matlab.net.URI(logoUrl);
            
            % Download logo
            thisFullpathSplit = pathsplit( mfilename("fullpath") );
            fileName = logoURI.Path(end);

            logoFilepath = fullfile('/',thisFullpathSplit{1:end-2}, fileName);
        end
    end

    methods (Static, Access = private)
        function columnSettings = loadMetatableColumnSettings()
            % Todo: represent as json?
            rootDir = fileparts(mfilename('fullpath'));
            filename = fullfile(rootDir, 'table_column_settings.mat');
            try
                S = load(filename, 'columnSettings');
                columnSettings = S.columnSettings;
            catch
                columnSettings = struct.empty;
            end
        end
    end
end
