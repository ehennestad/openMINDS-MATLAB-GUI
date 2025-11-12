function [itemNames, itemData] = uiEditHomogeneousList(metadataInstances, typeURI, metadataCollection)

    % Assumes we are editing a property of a schema...

    typePathSplit = strsplit(typeURI, '/');

    typeName = typePathSplit{end};
    className = typePathSplit{end-1};

    if nargin < 3
        metadataCollection = openminds.MetadataCollection();
    end

    numInstances = numel( metadataInstances );
    if numInstances >= 1
        structInstances = om.convert.toStruct( metadataInstances, metadataCollection );
    else
        structInstances = struct.empty;
    end

    title = sprintf( 'Edit %s for %s', typeName, className);

    typeName = class(metadataInstances);
    typeName = openminds.internal.utility.getSchemaShortName(typeName);

    if isempty(structInstances)
        referenceItem = om.convert.toStruct( feval(class(metadataInstances)), metadataCollection );
        editor = om.internal.window.ArrayEditor(structInstances, 'ItemType', typeName, 'Title', title, 'DefaultItem', referenceItem);
    else
        editor = om.internal.window.ArrayEditor(structInstances, 'ItemType', typeName, 'Title', title);
    end

    uim.utility.centerFigure(editor.UIFigure)
    editor.UIFigure.WindowStyle = 'alwaysontop';
    uiwait(editor, true)

    if ~isvalid(editor) || editor.FinishState ~= "Finished"
        [itemNames, itemData] = deal([]);
    else
        % Homogeneous...
        data = editor.Data;

        instances = {};

        for i = 1:numel(data)

            openmindsType = class(metadataInstances);

            iData = data(i);
            if isfield(iData, 'id')
                iInstance = feval( openmindsType, 'id', iData.id );
            else
                iInstance = feval( openmindsType );
            end
            instances{i} = om.convert.fromStruct(iInstance, iData, metadataCollection); %#ok<AGROW>

            if ~metadataCollection.contains( instances{i} )
                metadataCollection.add( instances{i} )
            end
        end

        % Convert to openminds instances to get labels...
        itemNames = cellfun(@(c) char(c), instances, 'UniformOutput', false);
        itemData = num2cell( instances );
    end

    delete(editor)
end
