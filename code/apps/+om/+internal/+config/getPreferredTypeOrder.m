function typeOrder = getPreferredTypeOrder(openmindsType, propertyName)

    % Todo: Write a test that checks that the names in preferred order
    % matches the names in the instance

    persistent preferences

    if isempty(preferences)
        preferences = loadPreferences();
    end

    shortName = openminds.internal.utility.getSchemaName(openmindsType);

    typeOrder = [];

    if isfield(preferences, shortName)
        preferredOrder = preferences.(shortName);
        if isfield(preferredOrder, propertyName)
            typeOrder = preferences.(shortName).(propertyName);
        end
    end
end

function prefs = loadPreferences()
    rootPath = om.internal.rootpath();
    filepath = fullfile(rootPath, 'config', 'preferredTypeOrder.json');
    prefs = jsondecode( fileread( filepath ) );
end
