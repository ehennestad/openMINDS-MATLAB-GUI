classdef UICollection < openminds.Collection
    
    % Questions:
    % What to use for keys in the metadata map
    %    - Short name; i.e Subject
    %    - Class name; i.e openminds.core.Subject
    %    - openMINDS type; i.e https://openminds.ebrains.eu/core/Subject

    % TODO:
    %   - [ ] Remove instances
    %   - [ ] Modify instances
    %   - [ ] Get instance
    %   - [ ] Get all instances of type

    %   - [ ] Add dynamic properties for each type in the collection?
    
    % Inherited: Public properties:
    %properties
        %Nodes (1,1) dictionary
    %end

    properties (Access = public)
        %metadata containers.Map
        graph digraph = digraph % Todo: Create a separate class?
    end

    properties (Access = private)
        EventStates
    end

    properties (Dependent) % Todo
        ContainedTypes (1,:) string % A list of types present in collection
    end

    events
        CollectionChanged
        InstanceAdded
        InstanceRemoved
        InstanceModified
        %TableUpdated ???
        %GraphUpdated ???
    end
    
    methods % Constructor
        function obj = UICollection(propValues, options)
            %obj.metadata = containers.Map;
            arguments
                propValues.?openminds.Collection
                options.Nodes = []
            end

            nvPairs = namedargs2cell(propValues);
            obj = obj@openminds.Collection(nvPairs{:});

            % Create a graph object
            obj.graph = digraph;
            
            obj.initializeEventStates()

            % If Nodes are provided, assign them and build the graph
            if ~isempty(options.Nodes)
                obj.Nodes = options.Nodes;
                obj.buildGraphFromNodes()
            end
        end
    end

    % Override Collection methods
    
    methods (Access = protected)
        function wasAdded = addNode(obj, instance, varargin)

            import om.ui.uicollection.event.CollectionChangedEventData

            % - Invoke superclass method
            wasAdded = addNode@openminds.Collection(obj, instance, varargin{:});
            
            if wasAdded
                % Add to graph
                % Question how to do this? Override subgraph? Or scan
                % all instances for links? Or use event listeners on instances?
                % obj.addInstanceToGraph(instance, ancestorInstance) % ?

                % - Notify collection changed
                if obj.EventStates('CollectionChanged')
                    evtData = CollectionChangedEventData('INSTANCE_ADDED', instance);
                    obj.notify('CollectionChanged', evtData)
                end
            end
        end
    
        function onNodesSet(obj)
            obj.buildGraphFromNodes();
        end
    end

    methods

        function addDeprecated(obj, metadataInstance)
            % This method is kept for backward compatibility
            % It now uses the add method from the superclass to add instances
            % to the Nodes dictionary and then updates the graph
            
            import om.ui.uicollection.event.CollectionChangedEventData

            % Add the instance to the collection using the superclass method
            obj.add(metadataInstance);
            
            % Update the graph with the new instance(s)
            for i = 1:numel(metadataInstance)
                thisInstance = metadataInstance(i);
                
                if ~isempty(obj.graph.Nodes)
                    foundNode = findnode(obj.graph, thisInstance.id);
                else
                    foundNode = 0;
                end

                if foundNode == 0
                    obj.graph = addnode(obj.graph, thisInstance.id);
                    obj.createInstanceListeners(thisInstance)
                end

                % Don't loop through controlled terms properties
                if isa(thisInstance, 'openminds.controlledterms.ControlledTerm')
                    continue
                end

                obj.addInstanceProperties(thisInstance)
            end

            % Notify that the collection has changed
            evtData = CollectionChangedEventData('INSTANCE_ADDED', metadataInstance);
            obj.notify('CollectionChanged', evtData)
        end

        function removeDeprecated(obj, metadataName)
            % This method is kept for backward compatibility
            % It now uses the remove method from the superclass
            
            % Get all instances of the specified type
            try
                instanceType = openminds.enum.Types(metadataName);
                instances = obj.list(instanceType);
                
                % Remove each instance from the collection
                for i = 1:numel(instances)
                    obj.remove(instances(i));
                    
                    % Remove the node from the graph
                    if ~isempty(obj.graph.Nodes)
                        foundNode = findnode(obj.graph, instances(i).id);
                        if foundNode > 0
                            obj.graph = rmnode(obj.graph, instances(i).id);
                        end
                    end
                end
            catch ME
                warning('Failed to remove instances of type %s: %s', metadataName, ME.message);
            end
        end

        function removeInstance(obj, type, index)
            % Get all instances of the specified type
            try
                instanceType = openminds.enum.Types(type);
                instances = obj.list(instanceType);
                
                % Check if index is valid
                if index > numel(instances)
                    error('Index exceeds the number of instances of type %s', type);
                end
                
                % Remove the instance at the specified index
                instanceToRemove = instances(index);
                obj.remove(instanceToRemove);
                
                % Remove the node from the graph
                if ~isempty(obj.graph.Nodes)
                    foundNode = findnode(obj.graph, instanceToRemove.id);
                    if foundNode > 0
                        obj.graph = rmnode(obj.graph, instanceToRemove.id);
                    end
                end
            catch ME
                warning('Failed to remove instance of type %s at index %d: %s', type, index, ME.message);
            end
        end

        function modifyInstance(obj, instanceId, propName, propValue)
            instance = obj.get(instanceId);
            if isempty(propValue)
                if openminds.utility.isMixedInstance( instance.(propName) ) || ...
                        openminds.utility.isInstance( instance.(propName) )
                    instance.(propName)(:) = [];
                else
                    instance.(propName)(:) = propValue;
                end
            else
                instance.(propName) = propValue;
            end
            obj.Nodes(instanceId) = {instance};
        end

        function updateMetadata(obj)
            % Update all metadata
        end

        function createListenersForAllInstances(obj)
        
            keyNames = obj.Nodes.keys();

            for i = 1:numel(keyNames)
                instances = obj.Nodes(keyNames{i});
                for j = 1:numel(instances)
                    if isa(instances(j), 'openminds.controlledterms.ControlledTerm')
                        continue
                    else
                        obj.createInstanceListeners(instances(j))
                    end
                end
            end
        end

        function createInstanceListeners(obj, instance)
            addlistener(instance, 'InstanceChanged', @obj.onInstanceChanged);
            addlistener(instance, 'PropertyWithLinkedInstanceChanged', ...
                @obj.onPropertyWithLinkedInstanceChanged);
        end

        function labels = getSchemaInstanceLabels(obj, schemaName, schemaId)
            
            if nargin < 3; schemaId = ''; end

            schemaName = obj.getSchemaShortName(schemaName);
            schemaInstances = obj.getSchemaInstances(schemaName);
            
            numSchemas = numel(schemaInstances);

            labels = arrayfun(@(i) sprintf('%s-%d', schemaName, i), 1:numSchemas, 'UniformOutput', false);
            if ~isempty(schemaId)
                isMatchedInstance = strcmp({schemaInstances.id}, schemaId);
                labels = labels(isMatchedInstance);
            end
        end

        function schemaInstance = getInstanceFromLabel(obj, schemaName, label)
            labels = obj.getSchemaInstanceLabels(schemaName);
            isMatch = strcmp(labels, label);
            
            schemaInstances = obj.getSchemaInstances(schemaName);
            schemaInstance = schemaInstances(isMatch);
        end

        function schemaInstances = getSchemaInstances(obj, schemaName)
            
            if contains(schemaName, '.')
                schemaName = obj.getSchemaShortName(schemaName);
            end

            if obj.hasType(schemaName)
                schemaInstances = obj.list(schemaName);
            else
                schemaInstances = [];
            end
        end
        
        function schemaInstance = getSchemaInstanceByIndex(obj, schemaName, index)
            schemaInstances = obj.getSchemaInstances(schemaName);
            schemaInstance = schemaInstances(index);
        end

        function autoAssignLabels(obj, schemaName)
            % Update labels if they are empty...
            try
                instanceType = openminds.enum.Types(schemaName);
                instances = obj.list(instanceType);
                
                if ~isempty(instances)
                    labels = obj.getSchemaInstanceLabels(schemaName);
                    
                    if isprop(instances, 'lookupLabel')
                        for i = 1:numel(instances)
                            if isempty(instances(i).lookupLabel) || strlength(instances(i).lookupLabel)==0
                                instances(i).lookupLabel = labels{i};
                            end
                        end
                    end
                end
            catch ME
                warning('Failed to auto-assign labels for type %s: %s', schemaName, ME.message);
            end
        end
    end

    methods (Access = public)
        function buildGraphFromNodes(obj)
            % buildGraphFromNodes Builds the graph representation from the Nodes dictionary
            %
            % This method iterates through all instances in the Nodes dictionary,
            % adds each instance as a node in the graph, creates listeners for each
            % instance, and adds edges between instances based on their relationships.
            %
            % Usage:
            %   obj.buildGraphFromNodes()
            
            % Reset the graph
            obj.graph = digraph;
            
            % Get all instance IDs from the Nodes dictionary
            instanceIds = obj.Nodes.keys();
            
            % First pass: Add all instances as nodes in the graph
            for i = 1:numel(instanceIds)
                instanceId = instanceIds{i};
                instance = obj.get(instanceId);

                %instanceName = sprintf('%s (%s)', string(instance), openminds.internal.utility.getSchemaShortName(class(instance)));
                
                nodeProps = table(string(instanceId), string(instance), string(openminds.internal.utility.getSchemaShortName(class(instance))), ...
                    'VariableNames', {'Name' 'Label', 'Type'});

                % Add the node to the graph
                try
                    obj.graph = addnode(obj.graph, nodeProps);
                catch ME
                    warning(ME.message)
                    obj.graph = addnode(obj.graph, instanceId);
                end
                
                % Create listeners for the instance (skip controlled terms)
                if ~isa(instance, 'openminds.controlledterms.ControlledTerm')
                    obj.createInstanceListeners(instance);
                end
            end
            
            % Second pass: Add edges between instances based on their relationships
            for i = 1:numel(instanceIds)
                instanceId = instanceIds{i};
                instance = obj.get(instanceId);
                
                % Skip controlled terms for edge creation
                if isa(instance, 'openminds.controlledterms.ControlledTerm')
                    continue;
                end
                
                % Process the instance's properties to find linked instances
                obj.addEdgesForInstance(instance);
            end
            
            fprintf('Graph built with %d nodes and %d edges\n', ...
                numnodes(obj.graph), numedges(obj.graph));
        end
        
        function addEdgesForInstance(obj, thisInstance)
            % addEdgesForInstance Adds edges to the graph for a given instance
            % This method examines the properties of an instance and adds edges
            % to the graph for any linked instances that are already in the collection.
            % Unlike addInstanceProperties, this method does not add instances to the collection.
            
            % Search through public properties of the metadata instance
            % for linked properties
            propertyNames = properties(thisInstance);

            for j = 1:length(propertyNames)
                propValue = thisInstance.(propertyNames{j});
                
                if isempty(propValue); continue; end

                if isa(propValue, 'openminds.abstract.Schema')
                    
                    if ~iscell(propValue)
                        % Add edges for array of instances
                        for k = 1:length(propValue)
                            % Check if the linked instance is in the collection
                            if isKey(obj.Nodes, propValue(k).id)
                                % Add an edge to the graph representing the relationship
                                obj.graph = addedge(obj.graph, thisInstance.id, propValue(k).id);
                            end
                        end
                    else
                        % Add edges for cell array of instances
                        for k = 1:length(propValue)
                            % Check if the linked instance is in the collection
                            if isKey(obj.Nodes, propValue{k}.id)
                                % Add an edge to the graph representing the relationship
                                obj.graph = addedge(obj.graph, thisInstance.id, propValue{k}.id);
                            end
                        end
                    end
                elseif openminds.utility.isMixedInstance(propValue)
                    % Add edges for array of instances
                    for k = 1:length(propValue)
                        % Check if the linked instance is in the collection
                        if isKey(obj.Nodes, propValue(k).Instance.id)
                            % Add an edge to the graph representing the relationship
                            obj.graph = addedge(obj.graph, thisInstance.id, propValue(k).Instance.id);
                        end
                    end
                end
            end
        end
    end
    
    methods (Access = private)

        function addInstanceProperties(obj, thisInstance)
            % Search through public properties of the metadata instance
            % for linked properties and add them to the graph
            propertyNames = properties(thisInstance);

            for j = 1:length(propertyNames)
                propValue = thisInstance.(propertyNames{j});
                
                if isempty(propValue); continue; end

                if isa(propValue, 'openminds.abstract.Schema')
                    
                    if ~iscell(propValue)
                        % Recursively add the new type to the collection and the new node to the graph
                        for k = 1:length(propValue)
                            % Add the instance to the collection
                            obj.add(propValue(k));

                            % Add the node to the graph if it doesn't exist
                            if ~isempty(obj.graph.Nodes)
                                foundNode = findnode(obj.graph, propValue(k).id);
                            else
                                foundNode = 0;
                            end

                            if foundNode == 0
                                obj.graph = addnode(obj.graph, propValue(k).id);
                                obj.createInstanceListeners(propValue(k));
                            end

                            % Add an edge to the graph representing the relationship
                            obj.graph = addedge(obj.graph, thisInstance.id, propValue(k).id);
                        end
                    else
                        % Recursively add the new type to the collection and the new node to the graph
                        for k = 1:length(propValue)
                            % Add the instance to the collection
                            obj.add(propValue{k});

                            % Add the node to the graph if it doesn't exist
                            if ~isempty(obj.graph.Nodes)
                                foundNode = findnode(obj.graph, propValue{k}.id);
                            else
                                foundNode = 0;
                            end

                            if foundNode == 0
                                obj.graph = addnode(obj.graph, propValue{k}.id);
                                obj.createInstanceListeners(propValue{k});
                            end

                            % Add an edge to the graph representing the relationship
                            obj.graph = addedge(obj.graph, thisInstance.id, propValue{k}.id);
                        end
                    end
                end
            end
        end
    
        function initializeEventStates(obj)
            obj.EventStates = containers.Map();
            
            eventNames = events(obj);

            for i = 1:numel(eventNames)
                currentName = eventNames{i};
                obj.EventStates(currentName) = matlab.lang.OnOffSwitchState.on;
            end
        end
    end

    methods (Access = private)

        function onPropertyWithLinkedInstanceChanged(obj, src, evt)
            
            % Todo: collect instance in evtdata
            obj.notify('InstanceModified', evt)
            fprintf('Linked instance of type %s was changed\n', class(src))

            removeIdx = find( strcmp(obj.graph.Edges.EndNodes(:,1), src.id) );

            obj.graph = rmedge(obj.graph, removeIdx);
            
            obj.addInstanceProperties(src)
        end

        function onInstanceChanged(obj, src, evt)
            
            obj.notify('InstanceModified', evt)
            fprintf('Instance of type %s was changed\n', class(src))
        end
    end

    methods % Methods for getting instances in table representations
        
        function [metaTable, instanceIDs] = getTable(obj, schemaName)
            
            instanceIDs = {};

            schemaName = openminds.internal.vocab.getSchemaName(schemaName);
            
            % Get instances of the specified type using the list method
            try
                instanceType = openminds.enum.Types(schemaName);
                schemaInstanceList = obj.list(instanceType);
            catch
                % Try using the string directly if conversion to enum fails
                schemaInstanceList = obj.list(schemaName);
            end

            if ~isempty(schemaInstanceList)
                % Get instance IDs
                instanceIDs = {schemaInstanceList.id};
                
                % Convert instances to a table
                instanceTable = schemaInstanceList.toTable();
                instanceTable.id = instanceIDs';
                
                % Replace linked instances with categoricals
                instanceTable = obj.replaceLinkedInstancesWithCategoricals(instanceTable, schemaName);

                % Create a MetaTable from the instance table
                metaTable = nansen.metadata.MetaTable(instanceTable, 'MetaTableClass', class(schemaInstanceList));
            else
                metaTable = [];
            end

            if nargout < 2
                clear instanceIDs
            end
        end

        function metaTable = joinTables(obj, schemaNames, options)
            
            arguments
                obj
                schemaNames
                options.JoinMethod = 'join' % innerjoin , join, outerjoin
            end

            instanceLinkee = schemaNames{1};
            instanceLinked = schemaNames{2};

            % Get tables for both schema types
            tableLinker = obj.getTable(instanceLinkee).entries;
            tableLinked = obj.getTable(instanceLinked).entries;
            
            % Get instances of both types
            instanceTypeLinkee = openminds.enum.Types(instanceLinkee);
            instanceTypeLinked = openminds.enum.Types(instanceLinked);
            instancesLinkee = obj.list(instanceTypeLinkee);
            instancesLinked = obj.list(instanceTypeLinked);
            
            % Add IDs to tables
            if ~isempty(instancesLinkee)
                tableLinker.id = {instancesLinkee.id}';
            end
            
            if ~isempty(instancesLinked)
                tableLinked.id = {instancesLinked.id}';
            end
            
            % Rename lookupLabel columns to avoid conflicts
            if ismember('lookupLabel', tableLinker.Properties.VariableNames)
                tableLinker = renamevars(tableLinker, 'lookupLabel', ['lookupLabel_', instanceLinkee]);
            end
            
            if ismember('lookupLabel', tableLinked.Properties.VariableNames)
                tableLinked = renamevars(tableLinked, 'lookupLabel', ['lookupLabel_', instanceLinked]);
            end

            % Get keys for joining
            % [leftKey, ~] = obj.getKeyPairsForJoin(instanceLinkee, instanceLinked);
            leftKey = 'id';  % Using ID as the key for now
            rightKey = 'id';

            % Perform the join
            joinFcn = str2func(options.JoinMethod);
            joinedTable = joinFcn(tableLinker, tableLinked, 'LeftKeys', leftKey, 'RightKeys', rightKey);
            
            % Remove the id column
            if ismember('id', joinedTable.Properties.VariableNames)
                joinedTable.id = [];
            end

            joinedClassName = sprintf('%s * %s', instanceLinkee, instanceLinked);
            
            metaTable = nansen.metadata.MetaTable(joinedTable, 'MetaTableClass', joinedClassName);
        end
    end

    methods (Access = protected) % Methods for getting instances in table representations
        
        function [leftKey, rightKey] = getKeyPairsForJoin(obj, schemaNameLinker, schemaNameLinkee)
            % Todo

            disp('a')
            leftKey = 'studiedState';
            rightKey = 'id';

            % Who is linked from who.
            % Need to check the schema and find the name of the property
            % who is linked... What if many properties can be linked to the
            % same schema??

            % For the linkee : Use property name
            %   Needed. List of linked properties and allowed link types

            % For the linked : Get id
        end
        
        function instanceTable = replaceLinkedInstancesWithCategoricals(obj, instanceTable, instanceType)
        % replaceLinkedInstancesWithCategoricals
        %
        %

            [numRows, numColumns] = size(instanceTable);
            %tempStruct = table2struct(instanceTable(1,:));
            
            className = openminds.enum.Types(instanceType).ClassName;
            metaSchema = openminds.internal.meta.Type(className);

            for i = 1:numColumns
                thisColumnName = instanceTable.Properties.VariableNames{i};

                % Todo: Check if columnName is an embedded type of
                % instanceType: In which case we dont want to replace with
                % categorical...

                try
                    % Get the value of the first row
                    firstValue = instanceTable{1,i};
                
                    % If the table column contains rows where the number of
                    % instances differ, need to extract instances from a cell
                    if iscell(firstValue); firstValue = [firstValue{:}]; end
                
                    % Get all the possible options.
                    if isa(firstValue, 'openminds.abstract.ControlledTerm')
                        options = eval(sprintf('%s.CONTROLLED_INSTANCES', class(firstValue)));
                        options = ["<no selection>", options]; %#ok<AGROW>

                    elseif isa(firstValue, 'openminds.abstract.Schema')
                            
                        if metaSchema.isPropertyValueScalar(thisColumnName)
                            className = string( openminds.enum.Types.fromClassName( class(firstValue) ) );
                            options = [sprintf("None (%s)", className),  obj.getSchemaInstanceLabels(className)];
                        else
                            options = [];
                        end
                    else
                        options = [];
                    end

                    if ~isempty(options)
                        % Question/todo: Should we make a protected
                        % categorical with this extra option?
                        rowValues = cell(numRows, 1);
                        for jRow = 1:numRows
                            thisValue =  instanceTable{jRow,i};
                            if iscell(thisValue); thisValue = [thisValue{:}]; end

                            if isempty(thisValue)
                                thisValue = options(1);
                            else
                                try
                                    % Todo: This need to be improved!!!
                                    thisValueStr = repmat("", 1, numel(thisValue));
                                    for k = 1:numel(thisValue)
                                        thisValueStr(k) = string( thisValue(k).getDisplayLabel() );
                                        if ~any( strcmp( thisValueStr(k), options ) )
                                            options(end+1) = thisValueStr; %#ok<AGROW>
                                        end
                                    end
                                    thisValue = thisValueStr;
                                catch
                                    thisValue = options(1);
                                end
                            end
                        end
                        
                        % Build categorical after all potential options are
                        % collected
                        uniqueOptions = unique(options);
                        uniqueOptions(uniqueOptions == "") = [];
                        for jRow = 1:numRows
                            rowValues{jRow} = categorical(thisValue, uniqueOptions, 'Protected', true);
                        end

                        instanceTable.(thisColumnName) = cat(1, rowValues{:});
                    else
                        if isa(firstValue, 'openminds.abstract.Schema')
                            % Convert to string values
                            if ~metaSchema.isPropertyValueScalar(thisColumnName)
                                rowValues = cell(numRows, 1);
                                for jRow = 1:numRows
                                    thisValue =  instanceTable{jRow,i};
                                    if isa(thisValue, 'cell')
                                        thisValueStr = arrayfun(@(x) string(x), thisValue{1});
                                    else
                                        thisValueStr = string(thisValue);
                                    end
                                    if isempty(thisValueStr)
                                        thisValueStr = "";
                                    elseif numel(thisValueStr) > 1
                                        thisValueStr = join(thisValueStr, '; ');
                                    end
                                    rowValues{jRow} = thisValueStr;
                                end
                                try
                                    instanceTable.(thisColumnName) = cat(1, rowValues{:});
                                catch
                                    keyboard
                                end
                            end
                        end
                    end

                catch ME
                    rethrow(ME)
                end
            end
        end
    end
    
    methods (Access = ?om.MetadataEditor)
        function enableEvent(obj, eventName)
            obj.EventStates(eventName) = matlab.lang.OnOffSwitchState.on;
        end

        function disableEvent(obj, eventName)
            obj.EventStates(eventName) = matlab.lang.OnOffSwitchState.off;
        end
    end

    methods (Static)
        function shortSchemaName = getSchemaShortName(fullSchemaName)
        %getSchemaShortName Get short schema name from full schema name
        %
        %   shortSchemaName = getSchemaShortName(fullSchemaName)
        %
        %   Example:
        %   fullSchemaName = 'openminds.core.research.Subject';
        %   shortSchemaName = om.ui.UICollection.getSchemaShortName(fullSchemaName)
        %   shortSchemaName =
        %
        %     'Subject'

            expression = '(?<=\.)\w*$'; % Get every word after a . at the end of a string
            shortSchemaName = regexp(fullSchemaName, expression, 'match', 'once');
            if isempty(shortSchemaName)
                shortSchemaName = fullSchemaName;
            end
        end

        function obj = fromCollection(collection)
            obj = om.ui.UICollection(...
                'Name', collection.Name, ...
                'Description', collection.Description);
            obj.Nodes = collection.Nodes;
            obj.TypeMap = collection.TypeMap;
            obj.buildGraphFromNodes()
        end

        function obj = loadobj(S)
            if isstruct(S)
                error('OMUI:UICollection:IncompatibleCollection', ...
                    ['Could not load current collection. It might have been ', ...
                    'created with an older version of this class'])
            end
            if isempty(S.EventStates)
                S.initializeEventStates()
            end
            obj = S;
        end
    end
end
