openminds.version(3);

scriptFolder = fileparts(fileparts(mfilename('fullpath')));

L = dir(fullfile(scriptFolder, '_testdata', '*.jsonld'));

metadataCollection = openminds.Collection(fullfile(L.folder, L.name));

uiCollection = om.ui.UICollection.fromCollection(metadataCollection);
om.MetadataEditor( uiCollection )