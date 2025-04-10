% This script requires the following repository: 
% https://github.com/ehennestad/EBRAINS-MATLAB
%
% That is a private repository, if you dont have access, let me know

filePath = fullfile(userpath, "openMINDS_MATLAB", "demo", "kg_collection.jsonld");
if isfile(filePath)
    kgCollection = ebrains.kg.KGCollection(filePath);
else
    kgCollection = ebrains.kg.KGCollection();
end

kgCollection.downloadRemoteInstances("Person")

tic
kgCollection.save(filePath) % Todo: serialize...
toc

% todo:
% load serialized instance without @type.


profile on
tic
kgCollection = ebrains.kg.KGCollection(filePath);
toc
profile viewer

% Load to mat-file
tic
save('test.mat', 'kgCollection', "-v7.3", "-nocompression")
toc

% Save to mat-file
tic
S = load('test.mat', 'kgCollection');
toc