function preferredOrder = getPreferredPropertyOrder(openmindsType)

    % Todo: Write a test that checks that the names in preferred order
    % matches the names in the instance

    persistent preferences

    if isempty(preferences)
        preferences = loadPreferences();
    end

    shortName = openminds.internal.utility.getSchemaName(openmindsType);

    propertyNames = properties(feval(openmindsType));

    if isfield(preferences, shortName)
        preferredOrder = preferences.(shortName);
    else
        preferredOrder = propertyNames;
    end
end

function prefs = loadPreferences()

    rootPath = om.internal.rootpath();
    filepath = fullfile(rootPath, 'config', 'preferredPropertyOrder.json');
    prefs = jsondecode( fileread( filepath ) );
end
