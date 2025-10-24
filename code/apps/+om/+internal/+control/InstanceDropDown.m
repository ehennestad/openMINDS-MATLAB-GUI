classdef InstanceDropDown < matlab.ui.componentcontainer.ComponentContainer ...
                          & om.internal.control.mixin.InheritableBackgroundColor

    % Todo: 
    %   [v] Add enumeration for supplementary action button
    %   [v] Only show download action if remote metadata collection is
    %       assigned
    %   [?] Add listener for Metadata collection events
    %   [v] Set mixed type (allowed types)
    %   [v] Update value properly...
    %   [v] How to deal with mixed type values???
    %   [ ] Test working with homogeneous and heterogeneous instances
    %   [ ] Test editing of items. Does item change? does label change?
    %   [ ] Create filter
    %   [ ] Flexibly wrap and unwrap comp.Value in mixed type class if 
    %       MetadataType is a mixed type
    %   [ ] Fill out controlled term instances if controlled term...
    %

    % Notes:
    % For efficiency, the dropdown is only populated with items, the
    % ItemsData is only represented in this class. For thousands of items +
    % itemsdata, dropdowns are very slow to update when changing items and
    % itemsdata, which is necessary if implementing filtering and
    % modifications of items/itemsdata (TODO)

    % Discussion
    %  - How will this be called? What if we need to create it without having
    %  - a value available.


    % Events with associated public callbacks
    events (HasCallbackProperty, NotifyAccess = private)
        ValueChanged
    end

    properties
        Value % NB: Need public set access
    end

    properties (Dependent)
        HasButton
        Enable
    end

    properties (Access = private)
        ValueIndex
    end

    properties
        ShowCreateAction = true
        MetadataTypeConstraints (1,:) om.internal.InstanceFilter
    end

    properties (Hidden)
        ActionButtonType (1,1) om.internal.control.enum.InstanceDropdownActionButton ...
            = om.internal.control.enum.InstanceDropdownActionButton.None
    end

    properties (SetAccess = private)
        Items (1,:) string = string.empty;
        ItemsData (1,:) cell = {};
    end

    properties (Constant, Access = private)
        DefaultActions = ["*Select a instance*", "*Create a new instance*", "*Download instances*"]
    end
    properties (SetAccess = immutable, Hidden)
        CustomActions (1,:) {mustBeA(CustomActions, 'om.internal.abstract.Action')} ...
            = om.internal.control.action.SelectInstance.empty
    end


    properties (SetAccess = private)
        MetadataType (1,1) string {om.internal.validator.mustBeTypeClassName} = missing
    end

    properties (SetAccess = private)
        MetadataCollection
        RemoteMetadataCollection
    end

    properties (SetAccess = private)
        UpstreamInstanceType (1,1) string = missing
        UpstreamInstancePropertyName (1,1) string = missing
    end

    properties (AbortSet = true)
        % MetadataType - The metadata type which is currently active/selected 
        % in this component
        ActiveMetadataType (1,1) openminds.enum.Types = "None"
    end

    % Properties that correspond to underlying components
    properties (Access = private, Transient, NonCopyable)
        GridLayout  matlab.ui.container.GridLayout
        DropDown    matlab.ui.control.DropDown
        ActionButton matlab.ui.control.Button
        TypeSelectionContextMenu om.internal.container.InstanceTypeMenu
    end
    
    % Properties that corresponds with internal states
    properties (Access = private)
        % HasRemoteInstances - Boolean flag indicating whether dropdown is
        % populated with remote instances (instances from a remote metadata 
        % collection)
        HasRemoteInstances = false

        % AllowedTypes - List of openMINDS types which this dropdown
        % supports. Note, this is either a scalar or a list if the dropdown
        % represents a mixed type.
        AllowedTypes (1,:) openminds.enum.Types

        SearchField
        SearchString = ''

        Actions (1,:) string
    end

    % Constructor
    methods
        function comp = InstanceDropDown(parent, propValues)
            arguments
                parent = []
                propValues.?matlab.ui.control.DropDown
                propValues.CreateFcn % ComponentContainer property
                propValues.ShowCreateAction = true
                propValues.MetadataCollection
                propValues.MetadataType (1,1) string = missing
                propValues.MetadataTypeConstraints (1,:) om.internal.InstanceFilter
                propValues.ActiveMetadataType (1,1) openminds.enum.Types = "None"
                propValues.UpstreamInstanceType (1,1) string = missing
                propValues.UpstreamInstancePropertyName (1,1) string = missing
                propValues.ActionButtonType (1,1) om.internal.control.enum.InstanceDropdownActionButton = "None"
                propValues.CustomActions (1,:) {mustBeA(propValues.CustomActions, 'om.internal.abstract.Action')} = ...
                    om.internal.control.action.SelectInstance.empty
                propValues.RemoteMetadataCollection
            end

            if ~isempty(parent)
                propValues.Parent = parent;
            end

            [propValues, propValuesSuper] = popPropValues(propValues, 'Parent', 'CreateFcn', 'Position');
            comp@matlab.ui.componentcontainer.ComponentContainer(propValuesSuper)

            if isfield(propValues, "ShowCreateAction")
                comp.ShowCreateAction = propValues.ShowCreateAction;
                propValues = rmfield(propValues, "ShowCreateAction");
            end

            % Assign metadata collection(s)
            [propValues, propValuesMetadataCollection] = popPropValues(propValues, ...
                'MetadataCollection', 'RemoteMetadataCollection');
            set(comp, propValuesMetadataCollection)

            % Assign upstream instance information
            [propValues, propValuesUpstream] = popPropValues(propValues, ...
                'UpstreamInstanceType', 'UpstreamInstancePropertyName');
            set(comp, propValuesUpstream)

            if isfield(propValues, "MetadataTypeConstraints")
                comp.MetadataTypeConstraints = propValues.MetadataTypeConstraints;
                propValues = rmfield(propValues, "MetadataTypeConstraints");
            end

            % Should be set before MetaDataType/ActiveMetadataType
            if isfield(propValues, "CustomActions") 
                if ~isempty(propValues.CustomActions)
                    comp.CustomActions = propValues.CustomActions;
                end
                propValues = rmfield(propValues, "CustomActions");
            end
            if ~isempty(comp.CustomActions)
                [comp.CustomActions(:).ParentComponent] = deal(comp);
                [comp.CustomActions(:).AncestorFigure] = deal(ancestor(comp, 'figure'));
            end

            % NB: In order to correctly initialize, MetaDataType needs to
            % be set after collections are set.
            if isfield(propValues, "MetadataType")
                comp.MetadataType = propValues.MetadataType;
                propValues = rmfield(propValues, "MetadataType");
            end
            if isfield(propValues, "ActiveMetadataType") 
                if propValues.ActiveMetadataType ~= "None"
                    comp.ActiveMetadataType = propValues.ActiveMetadataType;
                end
                propValues = rmfield(propValues, "ActiveMetadataType");
            end

            % Check if Value is provided
            if isfield(propValues, "Value")
                comp.MetadataType = class(propValues.Value);
                comp.Value = propValues.Value;
                propValues = rmfield(propValues, "Value");
            end

            [propValues, propValuesBtn] = popPropValues(propValues, 'ActionButtonType');
            set(comp, propValuesBtn)

            % Assign property values to dropdown
            set(comp.DropDown, propValues)

            % Initialize filter functionality
            % (TODO, Not functional yet)
            % comp.createFilter()
        end
    end

    % Public methods
    methods
        function updateValue(comp, newValue, previousValue, doNotify)

            if nargin < 4; doNotify = true; end

            % Todo: Wrap in mixed type if metadata type is mixed type...???
            if om.internal.validator.isMixedTypeClassName( comp.MetadataType )
                newValue = feval(comp.MetadataType, newValue);
                previousValue = feval(comp.MetadataType, previousValue);
            end
            
            comp.Value = newValue;

            evtData = matlab.ui.eventdata.ValueChangedData(...
                newValue, previousValue);
            
            if doNotify
                notify(comp, 'ValueChanged', evtData);
            end
        end
    
        function setValueFromId(comp, id, doNotify)

            if nargin < 3; doNotify = true; end
            
            % Handle controlled instances
            if startsWith(id, "https://openminds.ebrains.eu/instances/")
                [~, instanceName] = fileparts(id);
                if any(strcmp(string(comp.ItemsData), instanceName))
                    comp.updateValue(instanceName, comp.Value, doNotify)
                end

            else
                allIdentifiers = cellfun(@(c) c.id , comp.ItemsData, 'uni', 0);
                if any(strcmp(allIdentifiers, id))
                    newValue =  comp.ItemsData{ strcmp(allIdentifiers, id) };
                    comp.updateValue(newValue, comp.Value, doNotify)
                else
                    error('No instance with given identifier')
                end
            end
        end
    
        function resetSelection(comp)
            comp.Value = feval( sprintf('%s.empty', comp.MetadataType) );
        end
    end

    % Property set methods
    methods
        
        % Public properties
        function set.Value(comp, value)
            if isa(value, 'cell'); value = [value{:}]; end
            comp.Value = value;
            comp.postSetValue()
        end

        function set.ActiveMetadataType(comp, value)
            %value = comp.validateMetadataType(value);
            if strcmp(comp.ActiveMetadataType, value); return; end
            comp.ActiveMetadataType = value;
            comp.postSetActiveMetadataType()
        end

        function set.ActionButtonType(comp, value)
            comp.ActionButtonType = value;
            comp.postSetActionTypeButton()
        end

        function set.MetadataTypeConstraints(obj, value)
            obj.MetadataTypeConstraints = value;
            obj.postSetMetadataTypeConstraints()
        end

        % Immutable properties
        function set.MetadataType(comp, value)
            comp.MetadataType = value;
            comp.postSetMetadataType()
        end

        % Private properties

        function set.Items(comp, value)
            comp.Items = value;
            comp.postSetItems()
        end
               
        function set.ItemsData(comp, value)
            comp.ItemsData = value;
            comp.postSetItemsData()
        end

        function value = get.HasButton(comp)
            value = comp.ActionButtonType ~= "None";
        end

        function set.Enable(comp, value)
            comp.DropDown.Enable = value;
        end

        function value = get.Enable(comp)
            value = comp.DropDown.Enable;
        end
    end

    % Property post-set methods
    methods (Access = private)
        function postSetValue(comp)
            if isempty(comp.Value)                
                assert(isa(comp.Value, comp.MetadataType), ...
                    'Something unexpected happened (dropdown value is not of expected type)')

                comp.DropDown.ValueIndex = 1;
                return
            end
            
            % Find value index for given value, providing the value already
            % exists.
            valueIndex = [];
            for i = 1:numel(comp.ItemsData)
                if isstring(comp.ItemsData{i}) % For controlled instances.
                    if isequal(string(comp.Value), comp.ItemsData{i})
                        valueIndex = i; break
                    end
                elseif openminds.utility.isInstance(comp.ItemsData{i}) || ...
                        openminds.utility.isMixedInstance(comp.ItemsData{i})
                    if isequal(comp.Value, comp.ItemsData{i})
                        valueIndex = i; break
                    end
                else
                    error('Unsupported type for ItemsData elements')
                end
            end

            % Use ValueIndex to set DropDown selection in case some 
            % elements of comp.Items are identical
            if ~isempty(valueIndex)
                comp.DropDown.ValueIndex = valueIndex + numel(comp.Actions);
            else
                % If value is not part of the ItemsData, add it to the 
                % Items and ItemsData 
                comp.Items(end+1) = string(comp.Value);
                comp.ItemsData{end+1} = comp.Value;
                comp.DropDown.ValueIndex = numel(comp.DropDown.Items);
            end
        end

        function postSetActiveMetadataType(comp)
            % Need to set before updating items from collection!
            if ~isempty(comp.CustomActions)
                [comp.CustomActions(:).MetadataType] = comp.ActiveMetadataType;
            end

            comp.updateItemsFromCollection()

            if ~isempty(comp.TypeSelectionContextMenu)
                comp.TypeSelectionContextMenu.SelectedType = comp.ActiveMetadataType;
            end
        end
        
        function postSetMetadataType(comp)
            % Fill out allowed types.

            if ismissing(comp.MetadataType); return; end

            % Properly assign class name if only (short) name was provided
            [~, typeNames] = enumeration('openminds.enum.Types');
            if any(strcmp(comp.MetadataType, typeNames))
                comp.MetadataType = openminds.enum.Types(comp.MetadataType).ClassName;
                return
            end

            if om.internal.validator.isMixedTypeClassName( comp.MetadataType )
                allowedTypes = om.internal.getSortedTypesForMixedType( comp.MetadataType );
            else
                allowedTypes = comp.MetadataType;
            end

            allowedTypesShortNames = openminds.internal.utility.getSchemaShortName(allowedTypes);
            comp.AllowedTypes = openminds.enum.Types(allowedTypesShortNames);

            comp.ActiveMetadataType = comp.AllowedTypes(1);
        end

        function postSetMetadataTypeConstraints(comp)
            comp.updateItemsFromCollection()
        end

        function postSetItems(comp)
            actions = comp.getActionsWithTypeLabels();
            if isempty(comp.RemoteMetadataCollection)
                actions = actions(1:2);
            end

            if ~comp.ShowCreateAction
                actions(2) = [];
            end

            % Add custom action
            if ~isempty(comp.CustomActions)
                actions = [actions, comp.CustomActions.Label];
            end

            items = [actions, comp.Items];
            comp.Actions = actions;
            comp.DropDown.Items = items;

            comp.styleDropDownItems()
        end
                
        function postSetItemsData(comp)
            assert( numel(comp.ItemsData) == numel(comp.Items), ...
                "ItemsData must have the same number of elements as Items")
        end

        function postSetActionTypeButton(comp)
        % Update complementary button based on which button is selected
            comp.updateDropdownLayout()

            switch char(comp.ActionButtonType)
                case 'None'
                    if ~isempty(comp.ActionButton)
                        delete(comp.ActionButton)
                        comp.ActionButton(:) = [];
                    end
                    return

                case 'InstanceEditorButton'        
                    iconFilePath = om.internal.getIconPath('form');
                    callbackFcn = @comp.onEditInstanceButtonPushed;

                case 'TypeSelectionButton'
                    iconFilePath = om.internal.getIconPath('options');
                    callbackFcn = @comp.onChangeTypeButtonPushed;
                    comp.initializeTypeSelectionContextMenu()

                otherwise
                    return
            end

            if isempty(comp.ActionButton)
                comp.ActionButton = uibutton(comp.GridLayout);
                comp.ActionButton.Layout.Column = 2;
                comp.ActionButton.Text = "";
            end

            comp.ActionButton.Icon = iconFilePath;
            comp.ActionButton.ButtonPushedFcn = callbackFcn;
        end
    end

    % ComponentContainer methods
    methods (Access = protected)
        
        % Code that executes when the value of a public property is changed
        function update(comp)
            % Use this function to update the underlying components
        end

        % Create the underlying components
        function setup(comp)

            comp.Position = [1 1 100 22];
            comp.BackgroundColor = [0.94 0.94 0.94];

            % Create GridLayout
            comp.GridLayout = uigridlayout(comp);
            comp.GridLayout.ColumnWidth = {'1x', 25};
            comp.GridLayout.RowHeight = {'1x'};
            comp.GridLayout.Padding = [0 0 0 0];

            % Create DropDown
            comp.DropDown = uidropdown(comp.GridLayout);
            comp.DropDown.Layout.Row = 1;
            comp.DropDown.Layout.Column = [1, 2];
            comp.DropDown.ValueChangedFcn = ...
                matlab.apps.createCallbackFcn(comp, @onDropDownValueChanged, true);

            % Activate InheritableBackgroundColor functionality
            comp.addBackgroundColorLinkTargets(comp.GridLayout)
            comp.activateBackgroundColorInheritance()
        end
    end

    % Component callbacks
    methods (Access = private)
        % Value changed function: DropDown
        function onDropDownValueChanged(comp, event)
            
            value = comp.DropDown.Value;
            valueIndex = comp.DropDown.ValueIndex;

            if any(strcmp(value, [comp.CustomActions.Label]))
                idx = find(strcmp(value, [comp.CustomActions.Label]));
                [wasSuccess, newValue] = comp.CustomActions(idx).execute();
       
                % Todo: append to metadata collection
                if ~wasSuccess % Reset dropdown selection
                    comp.DropDown.Value = event.PreviousValue;
                    return
                end
                
            elseif any( strcmp(value, comp.Actions) )
                
                switch comp.DefaultActions(valueIndex)

                    case "*Select a instance*"
                        % This should update the component's value with an
                        % empty (null) instance
                        newValue = feval(sprintf("%s.empty", comp.ActiveMetadataType.ClassName));
                        wasSuccess = true;

                    case "*Create a new instance*"
                        [wasSuccess, newValue] = comp.createNewInstance();
                    
                    case "*Download instances*"
                        wasSuccess = comp.downloadRemoteInstances(); %#ok<NASGU>
                        comp.DropDown.ValueIndex = event.PreviousValueIndex;
                        return

                    otherwise
                        error('Something unexpected occured')
                end
                
                if ~wasSuccess % Reset dropdown selection
                    comp.DropDown.Value = event.PreviousValue;
                    return
                end

            else
                adjustedValueIndex = valueIndex - numel(comp.Actions);
                newValue = comp.ItemsData{adjustedValueIndex};
            end

            if event.PreviousValueIndex ~= 1
                previousValueIndex = event.PreviousValueIndex - numel(comp.Actions);
                previousValue = comp.ItemsData{previousValueIndex};
            else
                previousValue = feval(sprintf("%s.empty", comp.MetadataType));
            end

            comp.updateValue(newValue, previousValue)
        end

        function onDropDownOpened(comp, ~, ~)
        % Reset search / filter
            comp.SearchString = '';
            comp.DropDown.Tooltip = comp.SearchString;
            
            comp.Items = comp.Items; % Trigger update of DropDown items

            comp.SearchField.Value = comp.SearchString;
            comp.SearchField.Visible = true;
        end

        function onKeyPressed(comp, src, evt)
            disp(src.CurrentObject)
            if src.CurrentObject == comp.DropDown
                if string(evt.Key) == "backspace"
                    if numel(comp.SearchString) >= 1
                        comp.SearchString = comp.SearchString(1:end-1);
                    else
                        comp.SearchString = '';
                    end
                elseif ~isempty(regexp(evt.Character, '\w', 'once'))
                    comp.SearchString = [comp.SearchString, evt.Key];
                end

                isMatch = contains(comp.Items, comp.SearchString, 'IgnoreCase', true);
                
                if ~isempty(comp.SearchString)
                    comp.DropDown.ItemsData = {};
                    comp.DropDown.Items = comp.Items(isMatch);
                   % comp.DropDown.Value = comp.DropDown.Items{1};
                    comp.SearchField.Visible = true;

                    %comp.DropDown.Items{1} = comp.SearchString;
                    
                    % if ~isempty(comp.ItemsData)
                    %     comp.Value = comp.ItemsData{1};
                    % else
                    %     comp.Value = comp.DropDown.ItemsData{1};
                    % end
                else
                    %comp.DropDown.Items = comp.Items;
                    tic
                    comp.Items = comp.Items;
                    toc
                    %comp.DropDown.Value = comp.DropDown.Items{1};
                    comp.SearchField.Visible = false;

                    %comp.ItemsData = comp.ItemsData;
                end
                comp.SearchField.Value = comp.SearchString;
                comp.DropDown.Tooltip = comp.SearchString;
            end
        end
    
        function onMousePressed(comp, src, ~)
            if src.CurrentObject == comp.DropDown

            else
                comp.SearchField.Visible = false;
            end
        end
    
        function onEditInstanceButtonPushed(comp, ~, ~)
            comp.editInstance();
        end

        function onChangeTypeButtonPushed(comp, ~, evt)
            pos = getpixelposition(evt.Source, true);
            comp.TypeSelectionContextMenu.open(pos(1), pos(2))
        end

        function onTypeSelectionContectMenuClicked(comp, ~, evt)
            comp.ActiveMetadataType = evt.SelectedType;
        end
    end

    % Component methods (graphical) [creation/update]
    methods (Access = private)
        
        function createFilter(comp)
            comp.DropDown.DropDownOpeningFcn = @comp.onDropDownOpened;
            
            comp.SearchField = uieditfield(comp.GridLayout);
            comp.SearchField.Layout.Column = comp.DropDown.Layout.Column;
            comp.SearchField.Layout.Row = comp.DropDown.Layout.Row;
            comp.SearchField.Visible = false;
            comp.SearchField.Placeholder = "Type to search...";

            hFigure = ancestor(comp, 'figure');
            addlistener(hFigure, 'WindowKeyPress', @comp.onKeyPressed);
            addlistener(hFigure, 'WindowMousePress', @comp.onMousePressed);
        end

        function updateDropdownLayout(comp)
            if string(comp.ActionButtonType) == "None"
                comp.DropDown.Layout.Column = [1,2];
            else
                comp.DropDown.Layout.Column = 1;
            end
        end

        function updateItemsFromCollection(comp)
        % updatItemsFromCollection - Update items from metadata collections
        % 
        % Retrieving all instances of active type from metadata collections
        % and update component's Items and ItemsData properties.
            
            items = string.empty;
            itemsData = {};

            if ismissing(comp.ActiveMetadataType)
                % pass
            elseif ~ismissing(comp.UpstreamInstanceType) && openminds.utility.isEmbeddedType(comp.UpstreamInstanceType, comp.UpstreamInstancePropertyName)
                % pass
            else
                metadataType = string(comp.ActiveMetadataType);
                itemsData = comp.MetadataCollection.list( metadataType );

                if ~isempty(comp.RemoteMetadataCollection)
                    remoteInstances = comp.RemoteMetadataCollection.list( metadataType );
                    if ~isempty(remoteInstances)
                        itemsData = [itemsData, remoteInstances];
                        comp.HasRemoteInstances = true;
                    end
                end

                if contains(comp.ActiveMetadataType.ClassName, '.controlledterms')
                    controlledInstances = eval(sprintf('%s.CONTROLLED_INSTANCES', comp.ActiveMetadataType.ClassName));
                    controlledInstances = arrayfun(@(x)feval(comp.ActiveMetadataType.ClassName, x), controlledInstances);
                    itemsData = unique([itemsData, controlledInstances]);
                end

                if ~isempty(comp.MetadataTypeConstraints)
                    itemsData = comp.applyConstraints(itemsData);
                end

                if ~isempty(itemsData)
                    % Create items (string labels for items data)
                    items = arrayfun(@(i) string(char(i)), itemsData);
                end

                % Sort items for dropdowns by names/labels
                [items, sortIdx] = sort(items);
                itemsData = itemsData(sortIdx);
            end

            comp.Items = items;
            comp.ItemsData = num2cell(itemsData);
        end

        function actions = getActionsWithTypeLabels(comp)
            actions = comp.DefaultActions;

            if ismissing(comp.ActiveMetadataType)
                return
            end
            
            %activeTypeShortName = openminds.internal.utility.getSchemaShortName(comp.ActiveMetadataType);
            
            typeName = string(comp.ActiveMetadataType);

            % Get label from vocab
            label = openminds.internal.vocab.getSchemaLabelFromName(typeName);

            vowels = 'aeiouy';
            label = char(label);
            startsWithVowel = any( label(1) == vowels );

            actions = strrep(actions, 'instance', sprintf('%s instance', lower(label)));
            if startsWithVowel
                actions = strrep(actions, 'Select a', 'Select an');
            end

            if comp.HasRemoteInstances
                actions = strrep(actions, 'Download', 'Synch');
            end
                            
            actions = strrep(actions, ' instances', '');
            actions = strrep(actions, ' instance', '');

            %actions = string( compose('%s', actions) );
        end
    
        % Create context menu for selecting active type
        function initializeTypeSelectionContextMenu(comp)
            if isempty(comp.TypeSelectionContextMenu)
                hFigure = ancestor(comp, 'figure');
                if ~isempty(hFigure) && isvalid(hFigure)
                    comp.TypeSelectionContextMenu = ...
                        om.internal.container.InstanceTypeMenu(hFigure, ...
                        "Types", comp.AllowedTypes, ...
                        "SelectedType", comp.ActiveMetadataType, ...
                        "SelectionChangedFcn", @comp.onTypeSelectionContectMenuClicked );
                end
            end
        end
        
        function styleDropDownItems(comp)
            if ~isMATLABReleaseOlderThan("R2023a")
                removeStyle(comp.DropDown) % Remove old styles if any
                s1 = uistyle("FontAngle", "italic", "FontColor", [0.15,0.15,0.15]);
                
                for i = 1:numel(comp.Actions)
                    addStyle(comp.DropDown, s1, "item", i);
                end
            end
        end

        function hProgressDialog = openProgressDialogOnAction(comp, mode)

            arguments
                comp
                mode (1,1) string {mustBeMember(mode, ["create", "modify"])} = "create"

            end

            if mode == "create"
                messageStr = sprintf( "Create a new %s", comp.Tag );
            elseif mode == "modify"
                messageStr = sprintf( "Edit %s", comp.Tag );
            else
                error('ImpossibleError, Something happened that should not happen')
            end

            hFigure = ancestor(comp, 'figure');
            hProgressDialog = uiprogressdlg(hFigure, ...
                "Indeterminate", "on", ...
                "Message", messageStr );
        end
    end

    % Component methods (non-graphical)
    methods (Access = private)
    
        function [wasSuccess, itemData] = createNewInstance(comp)
            wasSuccess = false;

            emptyInstance = feval(comp.ActiveMetadataType.ClassName);

            hProgressDialog = comp.openProgressDialogOnAction("create");

            [itemData, item] = om.uiCreateNewInstance(...
                emptyInstance, ...
                comp.MetadataCollection, ...
                "UpstreamInstanceType", comp.UpstreamInstanceType, ...
                "UpstreamInstancePropertyName", comp.UpstreamInstancePropertyName);

            delete(hProgressDialog)

            if isempty(itemData)
                return
            else
                
                comp.Items = [comp.Items, item];
                comp.ItemsData = [comp.ItemsData, {itemData}];
                drawnow
                %comp.Value = itemData; %Todo!
                wasSuccess = true;
            end
        end

        function wasSuccess = editInstance(comp)
            wasSuccess = false;

            if isa(comp.Value, 'openminds.internal.abstract.MixedTypeSet')
                currentValue = comp.Value.Instance;
            else
                currentValue = comp.Value;
            end
            
            if comp.DropDown.ValueIndex == 1
                mode = "create";
            else
                mode = "modify";
            end
              
            hProgressDialog = comp.openProgressDialogOnAction(mode);

            % Need to pass some metainformation, like what types
            [newItemsData, newItems] = om.uiCreateNewInstance(...
                currentValue, comp.MetadataCollection, ...
                "UpstreamInstanceType", comp.UpstreamInstanceType, ...
                "UpstreamInstancePropertyName", comp.UpstreamInstancePropertyName, ...
                "Mode", mode);
        
            delete(hProgressDialog)

            if ~isempty(newItems) && ~isempty(newItemsData)
                if comp.DropDown.ValueIndex == 1
                    comp.Items = [comp.Items, newItems];
                    comp.ItemsData = [comp.ItemsData, {newItemsData}];
                    comp.updateValue(newItemsData, comp.Value)
                else
                    oldValueIndex = comp.DropDown.ValueIndex;
                    adjustedValueIndex = comp.DropDown.ValueIndex - numel(comp.Actions); %Todo: dependent property
                    comp.Items( adjustedValueIndex ) = newItems;
                    comp.ItemsData( adjustedValueIndex ) = {newItemsData};
                    
                    % Update dropdown selection
                    comp.DropDown.ValueIndex = oldValueIndex;
                end
            end

            wasSuccess = true;
        end
        
        function wasSuccess = downloadRemoteInstances(comp)
            try
                activeType = comp.ActiveMetadataType;
    
                % Create a progress bar
                hFigure = ancestor(comp, 'figure');
                hProgress = uiprogressdlg(hFigure, 'Message', 'Downloading instances...', 'Indeterminate', true);
    
                comp.RemoteMetadataCollection.downloadRemoteInstances(activeType, 'ProgressDialog', hProgress)
                comp.updateItemsFromCollection()
                wasSuccess = true;
            catch
                wasSuccess = false;
            end
        end
    
        function instances = applyConstraints(comp, instances)
            for i = 1:numel(comp.MetadataTypeConstraints)
                constraint = comp.MetadataTypeConstraints(i);
                instances = constraint.apply(instances);
            end
        end
    end
end

function [propValues, propValuesPopped] = popPropValues(propValues, varargin)
    propValuesPopped = struct;
    for i = 1:numel(varargin)
        if isfield(propValues, varargin{i})
            propValuesPopped.(varargin{i}) = propValues.(varargin{i});
            propValues = rmfield(propValues, varargin{i});
        end
    end
end
