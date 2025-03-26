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

            if ~isempty(options.Nodes)
                obj.Nodes = options.Nodes;
            end
            % Create a graph object
            obj.graph = digraph;
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
                evtData = CollectionChangedEventData('INSTANCE_ADDED', instance);
                obj.notify('CollectionChanged', evtData)
            end
        end
    end

    methods

        function addDeprecated(obj, metadataInstance)
            
            import om.ui.uicollection.event.CollectionChangedEventData

            instanceClass = class(metadataInstance);
            instanceName = obj.getSchemaShortName(instanceClass);
            
            if isKey(obj.metadata, instanceName)
                obj.metadata(instanceName) = [obj.metadata(instanceName), metadataInstance];
            else
                obj.metadata(instanceName) = metadataInstance;
            end

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

            evtData = CollectionChangedEventData('INSTANCE_ADDED', metadataInstance);
            obj.notify('CollectionChanged', evtData)
        end

        function removeDeprecated(obj, metadataName)
            obj.metadata.remove(metadataName);
            obj.graph = rmnode(obj.graph, metadataName);
        end

        function removeInstance(obj, type, index)
            instancesOfType = obj.metadata(type);
            instancesOfType(index)=[];
            obj.metadata(type) = instancesOfType;
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
            if isKey(obj.metadata, schemaName)
                labels = obj.getSchemaInstanceLabels(schemaName);
                instances = obj.SchemaInstances(schemaName);
                if isprop(instances, 'lookupLabel')
                    for i = 1:numel(instances)
                        if isempty(instances(i).lookupLabel) || strlength(instances(i).lookupLabel)==0
                            instances(i).lookupLabel = labels{i};
                        end
                    end
                end
            end
        end

    end

    methods (Access = private)

        function addInstanceProperties(obj, thisInstance)

            % Search through public properties of the metadata instance
            % for linked properties
            propertyNames = properties(thisInstance);

            for j = 1:length(propertyNames)
                propValue = thisInstance.(propertyNames{j});
                
                if isempty(propValue); continue; end

                if isa(propValue, 'openminds.abstract.Schema')
                    
                    if ~iscell(propValue)
                        % Recursively add the new type to the metadata property and the new node to the graph
                        for k = 1:length(propValue)
                            obj.add(propValue(k));

                            % Add the new node to the graph and an edge to the instance it is a property value of
                            obj.graph = addedge(obj.graph, thisInstance.id, propValue(k).id);
                        end
                    else
                        % Recursively add the new type to the metadata property and the new node to the graph
                        for k = 1:length(propValue)
                            obj.add(propValue{k});

                            % Add the new node to the graph and an edge to the instance it is a property value of
                            obj.graph = addedge(obj.graph, thisInstance.id, propValue{k}.id);
                        end
                    end
                end
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
            schemaInstanceList = obj.list(schemaName);

            if ~isempty(schemaInstanceList)
                %schemaInstanceList = obj.metadata(schemaName);
                
                instanceIDs = {schemaInstanceList.id};
                instanceTable = schemaInstanceList.toTable();
                instanceTable.id = instanceIDs';
                instanceTable = obj.replaceLinkedInstancesWithCategoricals(instanceTable, schemaName);

                metaTable = nansen.metadata.MetaTable(instanceTable, 'MetaTableClass', class(schemaInstanceList));
                % metaTable = Catalog(instanceTable, 'NameField', 'lookupLabel', 'ItemClass', class(schemaInstanceList));
                % metaTable.ItemRepresentation = 'object';
                % metaTable.ItemConstructorInputType = 'nvpairs';
                % 
                % metaTable.columnProperties = om.ui.initializeColumnAttributes(metaTable);
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

            tableLinker = obj.getTable(instanceLinkee).entries;
            tableLinker.id = {obj.metadata(instanceLinked).id}';
            tableLinked = obj.getTable(instanceLinked).entries;

            tableLinked.id = {obj.metadata(instanceLinked).id}';
            
            tableLinker = renamevars(tableLinker, 'lookupLabel', 'lookupLabel_Subject');
            tableLinked = renamevars(tableLinked, 'lookupLabel', 'lookupLabel_SubjectState');

            [leftKey, ~] = obj.getKeyPairsForJoin(instanceLinkee, instanceLinked);
            leftKey = 'id';
            rightKey = 'id';

            joinFcn = str2func(options.JoinMethod);

            joinedTable = joinFcn(tableLinker, tableLinked, 'LeftKeys', leftKey, 'RightKeys', rightKey);
            joinedTable.id = []; % Remove the id column

            joinedClassName = sprintf('%s * %s', instanceLinkee, instanceLinked);
            
            metaTable = nansen.metadata.MetaTable(joinedTable, 'MetaTableClass', joinedClassName);
        end

    end

    methods (Access = protected) % Methods for getting instances in table representations
        
        function [leftKey, rightKey] = getKeyPairsForJoin(obj, schemaNameLinker, schemaNameLinkee)
            
            
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
            metaSchema = openminds.internal.SchemaInspector(className);

            for i = 1:numColumns
                thisColumnName = instanceTable.Properties.VariableNames{i};

                % Todo: Check if columnName is an embedded type of
                % instanceType: In which case we dont want to replace with
                % categorical...

                try
                    % Get the value of the first row
                    thisValue = instanceTable{1,i};
                
                    % If the table column contains rows where the number of 
                    % instances differ, need to extract instances from a cell
                    if iscell(thisValue); thisValue = [thisValue{:}]; end
                
                    % Get all the possible options.
                    if isa(thisValue, 'openminds.abstract.ControlledTerm')
                        options = eval(sprintf('%s.CONTROLLED_INSTANCES', class(thisValue)));
                        options = ["<no selection>", options]; %#ok<AGROW>

                    elseif isa(thisValue, 'openminds.abstract.Schema')
                            
                        if metaSchema.isPropertyValueScalar(thisColumnName)
                            className = string( openminds.enum.Types.fromClassName( class(thisValue) ) ); 
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
                                    thisValue = string( thisValue.getDisplayLabel() );
                                    if ~any( strcmp( thisValue, options ) )
                                        options(end+1) = thisValue; %#ok<AGROW>
                                    end
                                catch
                                    thisValue = options(1);
                                end
                            end
    
                            rowValues{jRow} = categorical(thisValue, unique(options), 'Protected', true);
                        end
                        instanceTable.(thisColumnName) = cat(1, rowValues{:});
                    else
                        if isa(thisValue, 'openminds.abstract.Schema')
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

    methods 
        function exist()

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
        %   shortSchemaName = om.MetadataSet.getSchemaShortName(fullSchemaName)
        %   shortSchemaName =
        % 
        %     'Subject'

            expression = '(?<=\.)\w*$'; % Get every word after a . at the end of a string
            shortSchemaName = regexp(fullSchemaName, expression, 'match', 'once');
            if isempty(shortSchemaName)
                shortSchemaName = fullSchemaName;
            end
        end
    
    
    end

end
