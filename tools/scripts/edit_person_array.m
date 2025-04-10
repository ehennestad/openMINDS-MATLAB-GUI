addpath( genpath( fullfile(fileparts(openminds.internal.rootpath), 'tests') ) )
persons = personArray; % openminds/tests/oneOff

metadataCollection = openminds.MetadataCollection();
personStruct = om.convert.toStruct( persons, metadataCollection );


om.internal.window.ArrayEditor(personStruct, 'NameFcn', @(s) createName(s), 'ItemType', 'Person')


function name = createName(S)
    name = S.givenName + " " + S.familyName;
end
