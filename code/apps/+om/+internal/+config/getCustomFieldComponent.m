function config = getCustomFieldComponent(fieldName)
% getCustomFieldComponent - Specify if a non-default component should be
% used for a given property/field

    switch fieldName
        case 'description'
            config = @uitextarea; % Todo: Get and set height from a preference...
        otherwise
            config = [];
    end
end
