function instance = fromStruct(instance, data, metadataCollection) %#ok<INUSD>
% fromStruct - Update properties of a metadata instance from a structure

    propNames = properties(instance);

    for i = 1:numel(propNames)
        iPropName = propNames{i};
        iValue = instance.(iPropName);
        iNewValue = data.(iPropName);

        % Update with empty value
        if isempty(iNewValue)
            if ~isempty(iValue)
                if isstring(iValue) && iValue == ""
                    continue % Should not make scalar string empty
                end
                instance.(iPropName)(:) = [];
            end
            continue
        end

        % Type specific update
        if isenum(iValue)
            enumFcn = str2func( class(iValue) );
            instance.(iPropName) = enumFcn(iNewValue);
        elseif iscategorical(iValue)
            instance.(iPropName) = char(iNewValue);
        elseif isstring(iValue)
            instance.(iPropName) = char(iNewValue);
        elseif isnumeric(iValue)
            instance.(iPropName) = cast(iNewValue, class(instance.(iPropName)));
        elseif isa(iValue, 'openminds.abstract.ControlledTerm')
            linkedInstance = iNewValue;

            % Unpack instances from cell arrays (Todo: function for this)
            if isa(linkedInstance, 'cell')
                if numel(linkedInstance) == 1
                    assert(numel(linkedInstance)==1, "Expected length to be 1")
                    linkedInstance = linkedInstance{1};
                else
                    linkedInstance = [linkedInstance{:}];
                end
            end

            instance.(iPropName) = string(linkedInstance);

        elseif isa(iValue, 'openminds.abstract.Schema')
            linkedInstance = iNewValue;
            schemaName = class(instance.(iPropName));

            % Unpack instances from cell arrays
            if isa(linkedInstance, 'cell')
                if numel(linkedInstance) == 1
                    assert(numel(linkedInstance)==1, "Expected length to be 1")
                    linkedInstance = linkedInstance{1};
                else
                    linkedInstance = [linkedInstance{:}];
                end
            end

            % Get "null" instance
            if ~isa(linkedInstance, 'openminds.abstract.Schema')
                if isempty(linkedInstance)
                    linkedInstance = feval(sprintf('%s.empty', schemaName));
                elseif isa(linkedInstance, 'openminds.internal.abstract.MixedTypeSet')
                    % pass
                else
                    keyboard
                    % schemaInstance =
                    % metadataCollection.getInstanceFromLabel(schemaName,
                    % label); Todo: What case is this trying to solve?
                end
            end

            instance.(iPropName) = linkedInstance;
        elseif isa(iValue, 'openminds.internal.abstract.MixedTypeSet')
            linkedInstance = iNewValue;

            if isa(linkedInstance, 'cell')
                linkedInstance = [linkedInstance{:}];
            end

            instance.(iPropName) = linkedInstance;
        end
    end
end

function tf = isSchemaInstanceUnavailable(value)
    tf = ~isempty(regexp(char(value), 'No \w* available', 'once'));
end
