function [metadataInstance, instanceName] = uiCreateNewInstance(instanceSpec, metadataCollection, options)
% uiCreateNewInstance - Open form dialog window for entering instance information

%   Options (name-value pairs)
%       UpstreamInstanceType         : Type of upstream instance if the instance
%                                      to be created is a linked instance of
%                                      another instance.
%
%       UpstreamInstancePropertyName : Property name for upstream instance
%                                      if instance to be created is a linked
%                                      instance

    % Todo:
    % [ ] select structeditor based on matlab version / settings...
    % [ ] create new vs edit

    arguments
        instanceSpec
        metadataCollection = openminds.Collection([])
        options.UpstreamInstanceType (1,1) string = missing
        options.UpstreamInstancePropertyName (1,1) string = missing
        options.NumInstances = 1
        options.Mode (1,1) string {mustBeMember(options.Mode, ["create", "modify"])} = "create"
        options.ProgressMonitor = []
    end

    persistent formCache
    if isempty(formCache); formCache = dictionary(); end

    % Reset form cache during dev
    % formCache = dictionary(); % Todo: Remove

    instanceName = string.empty;

    if isa(instanceSpec, 'char') || isa(instanceSpec, 'string')
        mode = "create";
        typeClassFcn = str2func(instanceSpec);
        metadataInstance = arrayfun(@(i) typeClassFcn(), 1:options.NumInstances);
    else
        mode = "modify";
        if iscell(instanceSpec)
            metadataInstance = [instanceSpec{:}];
        else
            metadataInstance = instanceSpec;
        end
        instanceSpec = class(metadataInstance);
    end

    if isempty(metadataInstance)
        metadataInstance = feval(instanceSpec);
    end

    [SOrig, ~] = deal( metadataInstance(1).toStruct() );

    SNew = om.convert.toStruct( metadataInstance(1), metadataCollection );

    % Fill out options for each property
    propNames = fieldnames(SOrig);

    [~, ~, className] = fileparts(instanceSpec); % Todo: Create utility function for short name.
    [className, classNameLabel] = deal( extractAfter(className, ".") );

    % Todo: Improve pluralisation or skip altogether
    if options.NumInstances > 1; classNameLabel = [className, 's']; end

    if mode == "create"
        titleStr = sprintf('Create New %s', classNameLabel);
    elseif mode == "modify"
        titleStr = sprintf('Edit %s', classNameLabel);
    end

    % titleStr = om.internal.text.getEditorTitle(...
    %     "InstanceType", className, ...
    %     "UpstreamInstanceType", options.UpstreamInstanceType, ...
    %     "UpstreamInstancePropertyName", options.UpstreamInstancePropertyName, ...
    %     "Mode", "create");

    promptStr = sprintf('Fill out properties for %s', classNameLabel);
    % [SNew, wasAborted] = tools.editStruct(SNew, [], titleStr, 'Prompt', promptStr, 'Theme', 'light');

    if isConfigured(formCache) && isKey(formCache, className) && hasFigure(formCache(className))
        hEditor = formCache(className);
        hEditor.show();
        hEditor.Data = SNew;

        if ~isempty(options.ProgressMonitor)
            options.ProgressMonitor.Message = "Waiting for user input...";
        end

        if mode == "create"
            hEditor.OkButtonText = 'Create';
        elseif mode == "modify"
            hEditor.OkButtonText = 'Save';
        end

        uiwait(hEditor, true)

        wasAborted = hEditor.FinishState ~= "Finished";
        SNew = hEditor.Data;
        hEditor.hide();
        hEditor.reset()
    else

        % Todo: Consider passing instances directly...
        % hEditor = structeditor.StructEditorApp(metadataInstance, "Title", titleStr, 'LoadingHtmlSource', om.internal.getSpinnerSource());

        hEditor = structeditor.StructEditorApp(SNew, ...
            "Title", titleStr, ...
            'LoadingHtmlSource', om.internal.getSpinnerSource('pulsing_continous_themed'), ...
            'EnableNestedStruct', 'off' );

        if options.Mode == "create"
            hEditor.OkButtonText = 'Create';
        elseif options.Mode == "modify"
            hEditor.OkButtonText = 'Save';
        end

        if ~isempty(options.ProgressMonitor)
            options.ProgressMonitor.Message = "Waiting for user input...";
        end

        uiwait(hEditor, true)

        wasAborted = hEditor.FinishState ~= "Finished";
        SNew = hEditor.Data;
        hEditor.hide();
        hEditor.reset()
        formCache(className) = hEditor;
    end

    if wasAborted
        metadataInstance = [];
        return
    end

    if ~isempty(options.ProgressMonitor)
        options.ProgressMonitor.Message = "Updating metadata collection...";
    end

    for i = 1:numel(metadataInstance)
        % metadataInstance(i) = metadataInstance(i).fromStruct(SNew);
        metadataInstance(i) = om.convert.fromStruct(metadataInstance(i), SNew, metadataCollection);

        if ~metadataCollection.contains(metadataInstance(i))

            if ~ismissing(options.UpstreamInstanceType) && ...
                    openminds.utility.isEmbeddedType(options.UpstreamInstanceType, options.UpstreamInstancePropertyName)
                metadataCollection.add(metadataInstance(i), "AddSubNodesOnly", true)
            else
                metadataCollection.add(metadataInstance(i))
            end
        end
    end

    instanceName = arrayfun(@(i) char(i), metadataInstance, 'uni', 0);

    if ~nargout
        clear metadataInstance
    end

    if nargout < 2
        clear instanceName
    end
end

function tf = isSchemaInstanceUnavailable(value)
    tf = ~isempty(regexp(char(value), 'No \w* available', 'once'));
end
