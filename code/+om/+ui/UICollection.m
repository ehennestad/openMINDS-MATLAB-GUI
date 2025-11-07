classdef UICollection < openminds.Collection

    % Questions:
    % What to use for keys in the metadata map
    %    - Short name; i.e Subject
    %    - Class name; i.e openminds.core.Subject
    %    - openMINDS type; i.e https://openminds.ebrains.eu/core/Subject

    % TODO:
    %   - [ ] Modify instances
    %   - [ ] Get instance
    %   - [ ] Get all instances of type

    %   - [ ] Add dynamic properties for each type in the collection?

    % Inherited: Public properties:
    % properties
        % Nodes (1,1) dictionary
    % end

    properties (Access = public)
        % metadata containers.Map
        graph digraph = digraph % Todo: Create a separate class?
        ValidateGraphOnModification (1,1) logical = false % Control automatic validation for performance
    end

    properties (Access = private)
        EventStates
        InstanceListeners % Map to store listeners for each instance (instanceId -> listeners array)
    end

    properties (Dependent) % Todo
        ContainedTypes (1,:) string % A list of types present in collection
    end

    events
        CollectionChanged
        InstanceAdded
        InstanceRemoved
        InstanceModified
        GraphUpdated
        % TableUpdated ???
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

            % Initialize listener tracking
            obj.InstanceListeners = containers.Map('KeyType', 'char', 'ValueType', 'any');

            obj.initializeEventStates()

            obj.configureNodesIfNeeded()

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
                % Add to graph incrementally for better performance
                obj.addInstanceToGraph(instance);

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
        function remove(obj, instance)
        % remove - Remove metadata instance from the collection
        %
        %   This method overrides the superclass remove method to also:
        %   - Remove the node from the graph
        %   - Notify listeners that the collection has changed

            import om.ui.uicollection.event.CollectionChangedEventData

            % Get the instance ID
            if isstring(instance) || ischar(instance)
                instanceId = instance;
            elseif openminds.utility.isInstance(instance)
                instanceId = instance.id;
            else
                error('Unexpected type "%s" for instance argument', class(instance))
            end

            % Get the instance object before removing (for event notification)
            if isKey(obj.Nodes, instanceId)
                removedInstance = obj.get(instanceId);
            else
                % Instance not found, let superclass handle the error
                remove@openminds.Collection(obj, instance);
                return
            end

            % Remove from superclass (handles Nodes and TypeMap)
            remove@openminds.Collection(obj, instance);

            % Clean up listeners for this instance
            obj.deleteInstanceListeners(instanceId);

            % Remove the node from the graph incrementally
            obj.removeInstanceFromGraph(instanceId);

            % Notify that the collection has changed
            if obj.EventStates('CollectionChanged')
                evtData = CollectionChangedEventData('INSTANCE_REMOVED', removedInstance);
                obj.notify('CollectionChanged', evtData)
            end
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
            % It now uses the overridden remove method which handles
            % graph removal and event notification

            % Get all instances of the specified type
            try
                instanceType = openminds.enum.Types(metadataName);
                instances = obj.list(instanceType);

                % Remove each instance from the collection
                for i = 1:numel(instances)
                    obj.remove(instances(i));
                end
            catch ME
                warning('Failed to remove instances of type %s: %s', metadataName, ME.message);
            end
        end

        function removeInstance(obj, type, index)
            % Remove an instance of a specific type by index
            % This method uses the overridden remove method which handles
            % graph removal and event notification

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
            
            % Update graph edges for the modified instance
            obj.updateGraphAfterInstanceModification(instanceId);
        end

        function updateGraphAfterInstanceModification(obj, instanceId)
            % updateGraphAfterInstanceModification Updates graph edges after instance modification
            % This method ensures graph consistency when instance properties change
            
            if ~isKey(obj.Nodes, instanceId)
                return;
            end

            % Get the modified instance
            instanceCell = obj.Nodes(instanceId);
            instance = instanceCell{1};
            
            % Update node properties (label might have changed)
            if ~isempty(obj.graph.Nodes) && any(strcmp(obj.graph.Nodes.Name, instanceId))
                obj.updateNodeProperties(instanceId, instance);
            end
            
            % Remove all existing edges from and to this instance
            if ~isempty(obj.graph.Nodes) && any(strcmp(obj.graph.Nodes.Name, instanceId))
                % Remove outgoing edges (where this instance is the source)
                outgoingEdges = find(strcmp(obj.graph.Edges.EndNodes(:,1), instanceId));
                if ~isempty(outgoingEdges)
                    obj.graph = rmedge(obj.graph, outgoingEdges);
                end
                
                % Remove incoming edges (where this instance is the target)
                incomingEdges = find(strcmp(obj.graph.Edges.EndNodes(:,2), instanceId));
                if ~isempty(incomingEdges)
                    obj.graph = rmedge(obj.graph, incomingEdges);
                end
            end
            
            % Re-add edges based on current instance state
            obj.addEdgesForInstance(instance);
            
            % Re-add incoming edges from instances that reference this one
            obj.addReverseEdgesForInstance(instance);
        end

        function updateNodeProperties(obj, instanceId, instance)
            % updateNodeProperties Updates the properties of a node in the graph
            % This ensures node Label stays synchronized with instance state
            
            if isempty(obj.graph.Nodes) || ~any(strcmp(obj.graph.Nodes.Name, instanceId))
                return;
            end
            
            % Find the node index
            nodeIdx = find(strcmp(obj.graph.Nodes.Name, instanceId), 1);
            
            if isempty(nodeIdx)
                return;
            end
            
            % Update Label (display representation of instance)
            newLabel = string(instance);
            obj.graph.Nodes.Label(nodeIdx) = newLabel;
            
            % Notify that graph was updated
            if obj.EventStates('GraphUpdated')
                evtData = om.ui.uicollection.event.GraphUpdatedEventData('NODE_LABEL_CHANGED', instanceId, nodeIdx);
                obj.notify('GraphUpdated', evtData);
            end
        end

        function ensureGraphConsistency(obj, options)
            % ensureGraphConsistency Ensures graph is consistent with collection state
            %
            % Options:
            %   - 'Force': Force validation even if not needed
            %   - 'Repair': Automatically repair if inconsistent
            
            arguments
                obj
                options.Force (1,1) logical = false
                options.Repair (1,1) logical = true
            end
            
            % Skip validation for very large collections unless forced
            if ~options.Force && obj.count() > 1000
                return;
            end
            
            isValid = obj.validateGraphConsistency();
            
            if ~isValid && options.Repair
                obj.repairGraphConsistency();
            end
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
            % Skip if instance already has listeners or is a ControlledTerm
            if isa(instance, 'openminds.controlledterms.ControlledTerm')
                return;
            end
            
            instanceId = instance.id;
            if isKey(obj.InstanceListeners, instanceId)
                return; % Already has listeners
            end
            
            % Create and store listeners
            listeners = [
                addlistener(instance, 'InstanceChanged', @obj.onInstanceChanged);
                addlistener(instance, 'PropertyWithLinkedInstanceChanged', ...
                    @obj.onPropertyWithLinkedInstanceChanged)
            ];
            
            obj.InstanceListeners(instanceId) = listeners;
        end

        function deleteInstanceListeners(obj, instanceId)
            % Delete and remove listeners for an instance
            if isKey(obj.InstanceListeners, instanceId)
                listeners = obj.InstanceListeners(instanceId);
                % Delete each listener
                for i = 1:numel(listeners)
                    if isvalid(listeners(i))
                        delete(listeners(i));
                    end
                end
                % Remove from map
                remove(obj.InstanceListeners, instanceId);
            end
        end

        function labels = getSchemaInstanceLabels(obj, schemaName, schemaId)

            if nargin < 3; schemaId = ''; end

            schemaName = obj.getSchemaShortName(schemaName);
            schemaInstances = obj.getSchemaInstances(schemaName);

            numSchemas = numel(schemaInstances);

            labels = arrayfun(@(i) sprintf('%s-%d', schemaName, i), 1:numSchemas, 'UniformOutput', false);
            if ~isempty(schemaId)
                isMatchedInstance = strcmp([schemaInstances.id], schemaId);
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

        function isValid = checkGraphConsistency(obj, options)
            % checkGraphConsistency Public method to validate graph consistency
            %
            % Usage:
            %   isValid = checkGraphConsistency(obj)  % Basic check
            %   isValid = checkGraphConsistency(obj, 'Repair', true)  % Check and auto-repair
            %
            % Options:
            %   - 'Repair': Automatically repair inconsistencies (default: false)
            %   - 'Verbose': Display detailed information (default: true)
            
            arguments
                obj
                options.Repair (1,1) logical = false
                options.Verbose (1,1) logical = true
            end
            
            if options.Verbose
                fprintf('Validating graph consistency for collection with %d instances...\n', obj.count());
            end
            
            isValid = obj.validateGraphConsistency();
            
            if options.Verbose
                if isValid
                    fprintf('Graph consistency validation passed.\n');
                else
                    fprintf('Graph consistency validation failed.\n');
                end
            end
            
            if ~isValid && options.Repair
                if options.Verbose
                    fprintf('Attempting to repair graph inconsistencies...\n');
                end
                obj.repairGraphConsistency();
                isValid = obj.validateGraphConsistency();
                if options.Verbose
                    if isValid
                        fprintf('Graph repair successful.\n');
                    else
                        fprintf('Graph repair failed.\n');
                    end
                end
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
            if ~isConfigured(obj.Nodes)
                return
            end

            instanceIds = obj.Nodes.keys();

            % First pass: Add all instances as nodes in the graph
            for i = 1:numel(instanceIds)
                instanceId = instanceIds{i};
                instance = obj.get(instanceId);

                % instanceName = sprintf('%s (%s)', string(instance), openminds.internal.utility.getSchemaShortName(class(instance)));

                nodeProps = table(string(instanceId), string(instance), string(openminds.internal.utility.getSchemaShortName(class(instance))), ...
                    'VariableNames', {'Name', 'Label', 'Type'});

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
                
            % Optionally validate graph consistency after building
            if obj.ValidateGraphOnModification
                if ~obj.validateGraphConsistency()
                    warning('Graph inconsistency detected after building. This may indicate data corruption.');
                end
            end
        end

        function addEdgesForInstance(obj, thisInstance)
            % addEdgesForInstance Adds edges to the graph for a given instance
            % This method examines the properties of an instance and adds edges
            % to the graph for any linked instances that are already in the collection.
            % Unlike addInstanceProperties, this method does not add instances to the collection.

            % Collect all edges to add in batch for performance
            edgeSources = string.empty;
            edgeTargets = string.empty;
            
            % Search through public properties of the metadata instance
            % for linked properties
            propertyNames = properties(thisInstance);

            for j = 1:length(propertyNames)
                propValue = thisInstance.(propertyNames{j});

                if isempty(propValue); continue; end

                if isa(propValue, 'openminds.abstract.Schema')

                    if ~iscell(propValue)
                        % Collect edges for array of instances
                        for k = 1:length(propValue)
                            % Check if the linked instance is in the collection
                            if isKey(obj.Nodes, propValue(k).id)
                                % Add edge only if it doesn't already exist
                                if ~obj.edgeExists(thisInstance.id, propValue(k).id)
                                    edgeSources(end+1) = thisInstance.id; %#ok<AGROW>
                                    edgeTargets(end+1) = propValue(k).id; %#ok<AGROW>
                                end
                            end
                        end
                    else
                        % Collect edges for cell array of instances
                        for k = 1:length(propValue)
                            % Check if the linked instance is in the collection
                            if isKey(obj.Nodes, propValue{k}.id)
                                % Add edge only if it doesn't already exist
                                if ~obj.edgeExists(thisInstance.id, propValue{k}.id)
                                    edgeSources(end+1) = thisInstance.id; %#ok<AGROW>
                                    edgeTargets(end+1) = propValue{k}.id; %#ok<AGROW>
                                end
                            end
                        end
                    end
                elseif openminds.utility.isMixedInstance(propValue)
                    % Collect edges for array of mixed instances
                    for k = 1:length(propValue)
                        % Check if the linked instance is in the collection
                        if isKey(obj.Nodes, propValue(k).Instance.id)
                            % Add edge only if it doesn't already exist
                            if ~obj.edgeExists(thisInstance.id, propValue(k).Instance.id)
                                edgeSources(end+1) = thisInstance.id; %#ok<AGROW>
                                edgeTargets(end+1) = propValue(k).Instance.id; %#ok<AGROW>
                            end
                        end
                    end
                end
            end
            
            % Ensure all target nodes exist in the graph with proper properties
            % before adding edges (prevents addedge from auto-creating nodes without properties)
            if ~isempty(edgeTargets)
                uniqueTargets = unique(edgeTargets);
                for i = 1:length(uniqueTargets)
                    targetId = uniqueTargets(i);
                    if ~any(strcmp(obj.graph.Nodes.Name, targetId))
                        % Target node doesn't exist in graph yet, add it with proper properties
                        if isKey(obj.Nodes, targetId)
                            targetInstance = obj.get(targetId);
                            obj.addInstanceToGraph(targetInstance);
                        end
                    end
                end
            end
            
            % Add all collected edges in batch for better performance
            if ~isempty(edgeSources)
                % Concatenate edge sources and targets into a nx2 matrix
                % where n is the length of edge sources and targets
                edgeSources = reshape(edgeSources, [], 1);
                edgeTargets = reshape(edgeTargets, [], 1);

                edgeTable = table([edgeSources, edgeTargets], 'VariableNames', {'EndNodes'});
                obj.graph = addedge(obj.graph, edgeTable);
            end
        end

        function exists = edgeExists(obj, sourceId, targetId)
            % edgeExists Check if an edge already exists between two nodes
            % Returns true if edge exists, false otherwise
            if isempty(obj.graph.Edges)
                exists = false;
                return;
            end
            
            % Use findedge for efficient edge detection
            edgeIdx = findedge(obj.graph, sourceId, targetId);
            exists = (edgeIdx ~= 0);
        end

        function addInstanceToGraph(obj, instance)
            % addInstanceToGraph Adds a single instance to the graph
            % This method provides efficient graph updates without rebuilding the entire graph
            
            if ~openminds.utility.isInstance(instance)
                warning('Object is not a valid openMINDS instance');
                return;
            end
            
            instanceId = instance.id;
            
            % Add the instance as a node if it doesn't already exist
            if isempty(obj.graph.Nodes) || ~any(strcmp(obj.graph.Nodes.Name, instanceId))
                % Add node with properties (consistent with buildGraphFromNodes)
                nodeProps = table(string(instanceId), string(instance), ...
                    string(openminds.internal.utility.getSchemaShortName(class(instance))), ...
                    'VariableNames', {'Name' 'Label', 'Type'});
                
                try
                    obj.graph = addnode(obj.graph, nodeProps);
                catch ME
                    warning(ME.message)
                    obj.graph = addnode(obj.graph, instanceId);
                end
            end
            
            % Create listeners for the new instance (skips ControlledTerms)
            obj.createInstanceListeners(instance);
            
            % Add edges for this instance's relationships
            obj.addEdgesForInstance(instance);
            
            % Add reverse edges - instances that reference this new instance
            obj.addReverseEdgesForInstance(instance);
        end

        function addReverseEdgesForInstance(obj, newInstance)
            % addReverseEdgesForInstance Adds edges from existing instances to the new instance
            % This ensures bidirectional relationships are properly represented in the graph
            
            newInstanceId = newInstance.id;
            instanceIds = obj.Nodes.keys();
            
            for i = 1:numel(instanceIds)
                existingInstanceId = instanceIds{i};
                if strcmp(existingInstanceId, newInstanceId)
                    continue; % Skip self
                end
                
                existingInstanceCell = obj.Nodes(existingInstanceId);
                existingInstance = existingInstanceCell{1};
                
                % Check if existing instance references the new instance
                propertyNames = properties(existingInstance);
                for j = 1:length(propertyNames)
                    propValue = existingInstance.(propertyNames{j});
                    
                    if isempty(propValue); continue; end
                    
                    % Check various types of references
                    if obj.instanceReferencesTarget(propValue, newInstanceId)
                        % Add edge from existing to new instance only if it doesn't exist
                        if ~obj.edgeExists(existingInstanceId, newInstanceId)
                            obj.graph = addedge(obj.graph, existingInstanceId, newInstanceId);
                        end
                    end
                end
            end
        end

        function isReferenced = instanceReferencesTarget(~, propValue, targetId)
            % instanceReferencesTarget Check if a property value references the target instance
            isReferenced = false;
            
            if isa(propValue, 'openminds.abstract.Schema')
                if ~iscell(propValue)
                    % Array of instances
                    for k = 1:length(propValue)
                        if strcmp(propValue(k).id, targetId)
                            isReferenced = true;
                            return;
                        end
                    end
                else
                    % Cell array of instances
                    for k = 1:length(propValue)
                        if strcmp(propValue{k}.id, targetId)
                            isReferenced = true;
                            return;
                        end
                    end
                end
            elseif openminds.utility.isMixedInstance(propValue)
                % Mixed instance array
                for k = 1:length(propValue)
                    if strcmp(propValue(k).Instance.id, targetId)
                        isReferenced = true;
                        return;
                    end
                end
            end
        end

        function removeInstanceFromGraph(obj, instanceId)
            % removeInstanceFromGraph Removes an instance from the graph
            
            % Remove all edges involving this instance
            if ~isempty(obj.graph.Nodes) && any(strcmp(obj.graph.Nodes.Name, instanceId))
                % Find edges to remove
                edgesToRemove = find(strcmp(obj.graph.Edges.EndNodes(:,1), instanceId) | ...
                                   strcmp(obj.graph.Edges.EndNodes(:,2), instanceId));
                
                if ~isempty(edgesToRemove)
                    obj.graph = rmedge(obj.graph, edgesToRemove);
                end
                
                % Remove the node
                obj.graph = rmnode(obj.graph, instanceId);
            end
        end

        function isValid = validateGraphConsistency(obj)
            % validateGraphConsistency Validates that the graph is consistent with the collection state
            %
            % Returns:
            %   isValid - logical indicating if graph is consistent with collection
            %
            % This method performs several consistency checks:
            % 1. All collection instances are present as graph nodes
            % 2. All graph nodes correspond to collection instances  
            % 3. All edges represent valid relationships between instances
            % 4. No orphaned edges exist
            
            isValid = true;
            
            if ~isConfigured(obj.Nodes)
                % Empty collection should have empty graph
                isValid = numnodes(obj.graph) == 0;
                return;
            end
            
            collectionIds = obj.Nodes.keys();
            
            % Check 1: All collection instances should be graph nodes
            if ~isempty(obj.graph.Nodes)
                graphNodeIds = obj.graph.Nodes.Name;
                for i = 1:numel(collectionIds)
                    if ~any(strcmp(graphNodeIds, collectionIds{i}))
                        warning('Collection instance %s not found in graph', collectionIds{i});
                        isValid = false;
                    end
                end
                
                % Check 2: All graph nodes should correspond to collection instances
                for i = 1:numel(graphNodeIds)
                    if ~isKey(obj.Nodes, graphNodeIds{i})
                        warning('Graph node %s not found in collection', graphNodeIds{i});
                        isValid = false;
                    end
                end
            else
                % No graph nodes but collection has instances
                if ~isempty(collectionIds)
                    warning('Collection has instances but graph is empty');
                    isValid = false;
                end
            end
            
            % Check 3: Validate edges represent actual relationships
            if numedges(obj.graph) > 0
                edges = obj.graph.Edges.EndNodes;
                for i = 1:size(edges, 1)
                    sourceId = edges{i, 1};
                    targetId = edges{i, 2};
                    
                    % Verify both nodes exist in collection
                    if ~isKey(obj.Nodes, sourceId) || ~isKey(obj.Nodes, targetId)
                        warning('Edge from %s to %s involves non-existent instance', sourceId, targetId);
                        isValid = false;
                        continue;
                    end
                    
                    % Verify the relationship actually exists
                    sourceInstanceCell = obj.Nodes(sourceId);
                    sourceInstance = sourceInstanceCell{1};
                    
                    % Check if any property of the source instance references the target
                    hasValidRelationship = false;
                    propertyNames = properties(sourceInstance);
                    for propIdx = 1:length(propertyNames)
                        propValue = sourceInstance.(propertyNames{propIdx});
                        if obj.instanceReferencesTarget(propValue, targetId)
                            hasValidRelationship = true;
                            break;
                        end
                    end
                    
                    if ~hasValidRelationship
                        warning('Edge from %s to %s does not correspond to actual relationship', sourceId, targetId);
                        isValid = false;
                    end
                end
            end
        end

        function repairGraphConsistency(obj)
            % repairGraphConsistency Repairs graph inconsistencies by rebuilding from collection state
            %
            % This method should be called when validateGraphConsistency returns false.
            % It performs a full rebuild to ensure consistency.
            
            warning('Graph inconsistency detected. Rebuilding graph from collection state.');
            obj.buildGraphFromNodes();
        end
    end

    methods (Access = private)
        function configureNodesIfNeeded(obj)
            if isa(obj.Nodes, 'dictionary') && ~isConfigured(obj.Nodes)
                if exist('configureDictionary', 'builtin') == 5
                    obj.Nodes = configureDictionary('string', 'cell');
                else
                    obj.Nodes("dummy") = {''};
                    obj.Nodes = remove(obj.Nodes, "dummy");
                end
            end
        end

        function addInstanceProperties(obj, thisInstance)
            % addInstanceProperties Recursively adds linked instances to collection and graph
            % This method searches through an instance's properties, adds any linked
            % instances to the collection, and updates the graph accordingly.
            
            propertyNames = properties(thisInstance);

            for j = 1:length(propertyNames)
                propValue = thisInstance.(propertyNames{j});

                if isempty(propValue); continue; end

                if isa(propValue, 'openminds.abstract.Schema')
                    % Handle both cell and non-cell arrays of instances
                    if iscell(propValue)
                        instanceArray = [propValue{:}];
                    else
                        instanceArray = propValue;
                    end
                    
                    % Process each linked instance
                    for k = 1:length(instanceArray)
                        linkedInstance = instanceArray(k);
                        
                        % Add the instance to the collection
                        obj.add(linkedInstance);
                        
                        % Add to graph if not already present
                        if ~any(strcmp(obj.graph.Nodes.Name, linkedInstance.id))
                            obj.addInstanceToGraph(linkedInstance);
                        end
                    end
                end
            end
            
            % Now add edges for this instance using the consolidated method
            obj.addEdgesForInstance(thisInstance);
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
            % onPropertyWithLinkedInstanceChanged Called when a linked property changes
            % This requires full graph edge updates since relationships may have changed

            % Todo: collect instance in evtdata
            obj.notify('InstanceModified', evt)
            fprintf('Linked instance of type %s was changed\n', class(src))
            
            % Update node links. (Mis)Using addNode, should add method for
            % updating node links directly (TODO)
            obj.addNode(evt.IsPropertyOf, ...
                'AddSubNodesOnly', true, ...
                'AbortIfNodeExists', false);
            
            % Full update: edges need to be rebuilt since relationships changed
            obj.updateGraphAfterInstanceModification(src.id);
        end

        function onInstanceChanged(obj, src, evt)
            % onInstanceChanged Called when a non-linked property changes
            % Only node properties (like labels) need updating, no edge changes required

            obj.notify('InstanceModified', evt)
            fprintf('Instance of type %s was changed\n', class(src))
            
            % Efficient update: only update node properties, skip edge rebuild
            if ~isKey(obj.Nodes, src.id)
                return;
            end
            
            % Get the modified instance
            instanceCell = obj.Nodes(src.id);
            instance = instanceCell{1};
            
            % Update only node properties (label might have changed)
            if ~isempty(obj.graph.Nodes) && any(strcmp(obj.graph.Nodes.Name, src.id))
                obj.updateNodeProperties(src.id, instance);
            end
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
                instanceIDs = [schemaInstanceList.id];

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
                tableLinker.id = [instancesLinkee.id]'; % todo, check shape
            end

            if ~isempty(instancesLinked)
                tableLinked.id = [instancesLinked.id]'; % todo, check shape
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

        function [leftKey, rightKey] = getKeyPairsForJoin(obj, schemaNameLinker, schemaNameLinkee) %#ok<INUSD>
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
            % tempStruct = table2struct(instanceTable(1,:));

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
                        rowValues = strings(numRows, 1);
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
                            rowValues(jRow) = thisValue;
                        end

                        % Build categorical after all potential options are
                        % collected
                        uniqueOptions = unique(options);
                        uniqueOptions(uniqueOptions == "") = [];
                        rowValues = categorical(rowValues, uniqueOptions, 'Protected', true);
                        rowValues = num2cell(rowValues);

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
                                catch ME
                                    warning('Failed to concatenate values for column %s: %s', thisColumnName, ME.message);
                                    instanceTable.(thisColumnName) = rowValues;
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
            % Initialize InstanceListeners for older saved objects
            if isempty(S.InstanceListeners)
                S.InstanceListeners = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end
            obj = S;
        end
    end
end
