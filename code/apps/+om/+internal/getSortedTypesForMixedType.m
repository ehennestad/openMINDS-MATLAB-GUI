function typeClassNames = getSortedTypesForMixedType(mixedTypeClassName)
% getSortedTypesForMixedType - Get a sorted list of class names for mixed type
%
%   Note: Sorting is based on a preferred order, not alphabetical

    classNames = eval(sprintf('%s.ALLOWED_TYPES', mixedTypeClassName));

    splitMixedTypeClassName = strsplit(mixedTypeClassName, '.');

    schemaName = splitMixedTypeClassName{end-1};
    schemaName = openminds.internal.vocab.getSchemaName(schemaName);

    propertyName = splitMixedTypeClassName{end};

    % Sort allowed types
    typeClassNames = om.internal.config.sortTypes(schemaName, propertyName, classNames);
end
