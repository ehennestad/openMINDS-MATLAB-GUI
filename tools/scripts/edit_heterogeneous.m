
%dsv = openminds.core.DatasetVersion();
option = 3;

if option == 1
    cr = openminds.core.Copyright;
    %metadataCollection = openminds.MetadataCollection();
    metadataCollection = openminds.Collection();
    
    typeURI = cr.X_TYPE + "/" + "holder";
    om.uiEditHeterogeneousList(cr.holder, typeURI, metadataCollection)

elseif option == 2

    addpath( genpath( fullfile(fileparts(openminds.internal.rootpath), 'tests') ) )
    
    filePath = fullfile(userpath, "openMINDS_MATLAB", "demo", "datasetversion_gui.jsonld");
    
    if ~isfile(filePath)
        persons = personArray; % openminds/tests/oneOff
        
        dsv = openminds.core.DatasetVersion();
        dsv.author = persons;
        
        collection = openminds.Collection();
        collection.add(dsv)
        collection.save(filePath)
        mode = "create";
    else
        collection = openminds.Collection(filePath);
        dsv = collection.list("DatasetVersion");
        mode = "modify";
    end
    
    authors = dsv.author;
    
    typeURI = dsv.X_TYPE + "/" + "author";
    authors = openminds.internal.mixedtype.datasetversion.Author(authors);
    om.uiEditHeterogeneousList(authors, typeURI, collection)

    if ~isempty(dsv)
        collection.save(filePath)
    end

elseif option == 3
    
    dsv = openminds.core.DatasetVersion;
    metadataCollection = openminds.Collection();
    
    typeURI = dsv.X_TYPE + "/" + "keyword";
    om.uiEditHeterogeneousList(dsv.keyword, typeURI, metadataCollection)

end