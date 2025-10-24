function sortedTypes = sortTypes(schemaName, propertyName, types)

    propertyName = char(propertyName);
    propertyName(1) = lower(propertyName(1));

    preferredTypeOrder = om.internal.config.getPreferredTypeOrder(schemaName, propertyName);
    if ~isempty(preferredTypeOrder)

        shortNames = cellfun(@(c)openminds.internal.utility.getSchemaName(c), types, 'uni', 1);

        [~, idx] = intersect(preferredTypeOrder, shortNames);
        sortedTypes = types(idx);
    else
        sortedTypes = types;
    end
end
