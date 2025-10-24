function title = getEditorTitle(options)

    arguments
        options.InstanceType (1,1) string = missing
        options.UpstreamInstanceType (1,1) string = missing
        options.UpstreamInstancePropertyName (1,1) string = missing
        options.Mode (1,1) string {mustBeMember(options.Mode, ["create", "edit"])} = "create"
    end

    switch options.Mode
        case "create"
            action = "Create";

        case "edit"
            action = "Edit";
    end

    if ~ismissing(options.UpstreamInstanceType)
        title = sprintf( '%s %s for %s', ...
            action, ...
            options.UpstreamInstancePropertyName, ...
            options.UpstreamInstanceType);

    elseif ~ismissing(options.InstanceType)
        title = sprintf( '%s a new %s', action, options.InstanceType );

    else
        error('Provide "InstanceType" or "UpstreamInstanceType"')
    end
end
