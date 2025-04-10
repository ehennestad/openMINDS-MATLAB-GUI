function instance = fromStruct(instance, data, metadataCollection)

    propNames = properties(instance);

    for i = 1:numel(propNames)
        iPropName = propNames{i};
        iValue = instance.(iPropName);

        if isenum(iValue)
            enumFcn = str2func( class(iValue) );
            instance.(iPropName) = enumFcn(data.(iPropName));
        elseif iscategorical(iValue)
            instance.(iPropName) = char(data.(iPropName));
        elseif isstring(iValue)
            instance.(iPropName) = char(data.(iPropName));
        elseif isnumeric(iValue)
            instance.(iPropName) = cast(data.(iPropName), class(instance.(iPropName)));
        elseif isa(iValue, 'openminds.abstract.ControlledTerm')
            %instance.(iPropName) = char(data.(iPropName));

            linkedInstance = data.(iPropName);
            
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
            linkedInstance = data.(iPropName);
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
                elseif isa(linkedInstance, 'openminds.internal.abstract.LinkedCategory')
                    % pass
                else
                    keyboard
                    %schemaInstance = metadataCollection.getInstanceFromLabel(schemaName, label);
                end
            end
            
            instance.(iPropName) = linkedInstance;
        elseif isa(iValue, 'openminds.internal.abstract.LinkedCategory')
            linkedInstance = data.(iPropName);
            
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
