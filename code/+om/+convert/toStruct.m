function structInstance = toStruct(openMindsInstance, metadataCollection)
    
    if isempty( openMindsInstance )
        structInstance = struct.empty; return

    elseif numel( openMindsInstance ) > 1
        structInstance = cell(1, numel(openMindsInstance) );
        for i = 1:numel(structInstance)
            structInstance{i} = om.convert.toStruct( openMindsInstance(i), metadataCollection );
        end
        %structInstance = [structInstance{:}];
        return
    end

    % NB: Special case. Todo: Consider to make this more internal.
    if isa(openMindsInstance, 'openminds.internal.abstract.MixedTypeSet')
        openMindsInstance = openMindsInstance.Instance;
    end

    try
        structInstance = openMindsInstance.toStruct();
    catch
        keyboard
    end
    openMindsType = class(openMindsInstance);

    % Order fields according to settings/preferences
    propertyOrder = om.internal.config.getPreferredPropertyOrder( openMindsType );
    structInstance = orderfields(structInstance, propertyOrder);
    
    metaSchema = openminds.internal.meta.Type( openMindsInstance );

    % Fill out options for each property
    propNames = fieldnames(structInstance);

    for i = 1:numel(propNames)
        
        iPropName = propNames{i};
        iValue = structInstance.(iPropName);
        iConfig = [];
        customFcn = [];
        
        if isstring(iValue)
            if ismissing(iValue); iValue = ''; end
            if numel(iValue) > 1
                iValue = char(strjoin(iValue, '; ')); % Todo: reverse in fromStruct
            else
                iValue = char(iValue);
            end

        elseif isnumeric(iValue)
            iValue = double(iValue);

        elseif isdatetime(iValue)
            % pass

        elseif isenum(iValue) % Deprecated?
            [~, names] = enumeration( iValue );
            iValue = categorical(names(1), names);

        elseif isa(iValue, 'openminds.abstract.ControlledTerm')
            %names = eval( sprintf('%s.CONTROLLED_INSTANCES', class(iValue)));
            %iValue = categorical(names(1), names);
            
            if metaSchema.isPropertyValueScalar(iPropName)
                customFcn = @getConfigForScalarValue;
            else
                customFcn = @getConfigForNonScalarValue;
            end

        elseif isa(iValue, 'openminds.abstract.Schema')
            if metaSchema.isPropertyValueScalar(iPropName)
                customFcn = @getConfigForScalarValue;
            else
                customFcn = @getConfigForNonScalarValue;
            end

        elseif isa(iValue, 'openminds.internal.abstract.MixedTypeSet') % oneOf/anyOf
            if metaSchema.isPropertyValueScalar(iPropName)
                customFcn = @getConfigForHeterogeneousScalarValue;
            else
                customFcn = @getConfigForHeterogeneousNonScalarValue;
            end

        else
            warning('Values of type %s is not dealt with', class(iValue))
        end

        if ~isempty(customFcn)
            [iValue, iConfig] = customFcn(iPropName, iValue, openMindsInstance, metadataCollection);
        else
            iConfig = om.internal.config.getCustomFieldComponent(iPropName);
        end

        structInstance.(iPropName) = iValue;
        if ~isempty(iConfig)
            iPropName_ = [iPropName, '_'];
            structInstance.(iPropName_) = iConfig;
        end
    end

    % Add @id and @type
    structInstance.id = openMindsInstance.id;
    structInstance.id_ = 'hidden';

    % Todo: Use matlab class name, not @type...
    structInstance.type = openMindsInstance.X_TYPE;
    structInstance.type_ = 'hidden';
end

% Local functions

function [value, config] = getConfigForScalarValue(name, value, openMindsInstance, metadataCollection)

    arguments
        name
        value
        openMindsInstance
        metadataCollection
    end

    config = @(h, varargin) om.internal.control.InstanceDropDown(h, ...
        "MetadataType", class(value), ...
        "MetadataCollection", metadataCollection, ...
        "ActionButtonType", "InstanceEditorButton", ...
        "UpstreamInstanceType", openminds.internal.utility.getSchemaName(class(openMindsInstance)), ...
        "UpstreamInstancePropertyName", name);
end

function [value, config] = getConfigForNonScalarValue(name, value, openMindsInstance, metadataCollection)

    % Todo: Use "Upstream..." instead, like for InstanceDropDown
    propertyTypeName = openMindsInstance.X_TYPE + "/" + name;

    editItemsFcn = @(value, varargin) ...
        om.uiEditHeterogeneousList(value, propertyTypeName, metadataCollection );
    
    items = arrayfun(@(x) string(x), value);
    if isempty(value)
        itemsData = {value};
    else
        itemsData = num2cell( value );
    end

    config = @(h, varargin) om.internal.control.ListControl(h, ...
        'Items', items, ...
        'ItemsData', value, ...
        'EditItemsFcn', editItemsFcn);
    %value = itemsData;
end

function [value, config] = getConfigForHeterogeneousScalarValue(name, value, openMindsInstance, metadataCollection)
        
    arguments
        name char
        value openminds.internal.abstract.MixedTypeSet
        openMindsInstance openminds.abstract.Schema
        metadataCollection openminds.Collection
    end

    config = @(h, varargin) om.internal.control.InstanceDropDown(h, ...
        "MetadataType", class(value), ...
        "MetadataCollection", metadataCollection, ...
        "ActionButtonType", "TypeSelectionButton", ...
        "UpstreamInstanceType", openminds.internal.utility.getSchemaName(class(openMindsInstance)), ...
        "UpstreamInstancePropertyName", name);
end

function [value, configFcn] = getConfigForHeterogeneousNonScalarValue(name, value, openMindsInstance, metadataCollection)
    
    propertyTypeName = openMindsInstance.X_TYPE + "/" + name;

    editItemsFcn = @(value, varargin) ...
        om.uiEditHeterogeneousList(value, propertyTypeName, metadataCollection );
    
    items = arrayfun(@(x) string(x), value);

    % Todo: Clarify why this needs to be a cell array
    if isempty(value)
        itemsData = {value};
    else
        itemsData = num2cell( value );
    end

    configFcn = @(h, varargin) om.internal.control.ListControl(h, ...
        'Items', items, ...
        'ItemsData', value, ...
        'EditItemsFcn', editItemsFcn);

    %value = itemsData;
end
