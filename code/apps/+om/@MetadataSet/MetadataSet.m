classdef MetadataSet < handle & matlab.mixin.CustomDisplay
    
%   Todo:
%       - [ ] Rename to MetadataCollection
%       - [ ] Make sure labels are not duplicated. Validation of new labels
%             against the set of labels.
%       - [ ] Make sure embedded types are not added to set??
%   

%   Questions: What happens in the kg if you try to assign the same label?
    
    properties (Dependent, Hidden)
        SchemaNames
    end
    
    properties
        SchemaInstances struct = struct
        SchemaGraph % Todo: Make a graph for all the schemas in the model. Use uids, and then labels for display?
    end

    events % Todo: What events make sense...
        SchemaAdded
        SchemaRemoved
        SchemaGraphUpdated
    end

    methods
        
% %         function sObj = saveobj(obj)
% % 
% %             sObj=struct(obj);
% %         end

        function add(obj, schemaInstance)
            
            schemaPathName = class(schemaInstance);
            schemaName = obj.getSchemaShortName(schemaPathName);

            n = numel(schemaInstance);

            if ~isfield( obj.SchemaInstances, schemaName )
                subs = struct('type', {'.', '()'}, 'subs', {schemaName, {1:n}});
                obj.SchemaInstances = subsasgn(obj.SchemaInstances, subs, schemaInstance);
            else
                obj.SchemaInstances.(schemaName)(end+1:end+n) = schemaInstance;
            end
            
            % Todo: Autogenerate internalIdentifier and lookupLabel
            
            % Update labels if they are empty...
            obj.autoAssignLabels(schemaName)
        end

        function remove(obj, schemaInstance)
            
            
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

            if isfield(obj.SchemaInstances, schemaName)
                schemaInstances = obj.SchemaInstances.(schemaName);
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
            labels = obj.getSchemaInstanceLabels(schemaName);
            instances = obj.SchemaInstances.(schemaName);
            if isprop(instances, 'lookupLabel')
                for i = 1:numel(instances)
                    if isempty(instances(i).lookupLabel) || strlength(instances(i).lookupLabel)==0
                        instances(i).lookupLabel = labels{i};
                    end
                end
            end
        end

    end

    methods % Methods for getting instances in table representations
        
        function metaTable = getTable(obj, schemaName)

            if isfield(obj.SchemaInstances, schemaName)
                schemaInstanceList = obj.SchemaInstances.(schemaName);

                instanceTable = schemaInstanceList.toTable();
                instanceTable = obj.replaceLinkedInstancesWithCategoricals(instanceTable, schemaName);

                metaTable = nansen.metadata.MetaTable(instanceTable, 'MetaTableClass', class(schemaInstanceList));
            else
                metaTable = [];
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
            tableLinker.id = {obj.SchemaInstances.(instanceLinked).id}';
            tableLinked = obj.getTable(instanceLinked).entries;

            tableLinked.id = {obj.SchemaInstances.(instanceLinked).id}';
            
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

            [numRows, numColumns] = size(instanceTable);
            %tempStruct = table2struct(instanceTable(1,:));
            
            for i = 1:numColumns
                thisColumnName = instanceTable.Properties.VariableNames{i};

                % Todo: Check if columnName is an embedded type of
                % instanceType: In which case we dont want to replace with
                % categorical...


                thisValue =  instanceTable{1,i};
                if isa(thisValue, 'openminds.abstract.Schema') && ~isa(thisValue, 'openminds.controlledterms.ControlledTerm')
                    className = openminds.abstract.Schema.getSchemaShortName(class(thisValue)); % Todo: get this in a better way
                    % obj.getSchemaInstanceLabels(className)

                    options = [sprintf("None (%s)", className),  obj.getSchemaInstanceLabels(className)];

                    rowValues = cell(numRows, 1);
                    for jRow = 1:numRows
                        thisValue =  instanceTable{jRow,i};

                        if isempty(thisValue)
                            thisValue = options(1);
                        else
                            try
                                % Todo: This needs to be improved!!!
                                thisValue = thisValue.getDisplayLabel;
                                options(end+1) = thisValue; %#ok<AGROW>
                            catch
                                thisValue = options(1);
                            end
                        end

                        rowValues{jRow} = categorical(thisValue, unique(options));
                    end
                    instanceTable.(thisColumnName) = cat(1,rowValues{:});
                end
            end            
        end

    end

    methods % Methods for getting instances in graph representations

    end

    methods % Set/get
        function schemaNames = get.SchemaNames(obj)
            schemaNames = fieldnames(obj.SchemaInstances);
        end
    end

    methods (Access = protected)

        function groups = getPropertyGroups(obj)
            propListing = obj.SchemaInstances;
            groups = matlab.mixin.util.PropertyGroup(propListing);
        end

% %           function sobj = saveobj(obj)
% %             % Call superclass saveobj method
% %             sobj = saveobj@super(obj);
% %           end

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
    
    methods (Static)
        function obj = loadobj(S)
            obj = S;
            schemaNames = fieldnames(obj.SchemaInstances);
            for i = 1:numel(schemaNames)
                obj.autoAssignLabels(schemaNames{i})
            end
        end
    end
end