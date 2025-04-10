classdef NCBITaxonSearch < om.internal.abstract.Action

    properties (Constant)
        Name = "Search NCBI Taxon"
        Description = "Let's user search for species instances in the NCBI Taxon Database";
    end

    properties (Constant, Access=protected)
        LabelTemplate = "*Add a instance from NCBITaxon*"
    end

    methods
        function [wasSuccess, metadataInstance] = execute(obj)

            wasSuccess = false;
            metadataInstance = [];

            searchTerm = inputdlg('Enter the name of a species:');
            if searchTerm == 0
                obj.throwUiError("Operation canceled", 'User Canceled')
                return
            else
                searchTerm = searchTerm{1};
            end

            if ~isempty(obj.AncestorFigure)
                progressDialog = uiprogressdlg(obj.AncestorFigure, ...
                    "Indeterminate", "on", ...
                    'Title','Please Wait!', ...
                    "Message", "Searching for species in the NCBI Taxonomy database...");
                progressCleanup = onCleanup(@() delete(progressDialog));
            else
                progressCleanup = []; %#ok<NASGU>
            end

            [~, uuid] = ndi.database.metadata_app.fun.SearchSpecies(searchTerm);
            clear progressCleanup

            if (uuid == -1)
                errMessage = sprintf('The entered value is not a valid scientific name, common name or synonym.');
                obj.throwUiError(errMessage, 'Invalid species name')
                return
            else
                [name, ontologyIdentifier, synonym] = ndi.database.metadata_app.fun.getSpeciesInfo(uuid);
                
                newSpecies = openminds.controlledterms.Species(...
                    'name', name, ...
                    'preferredOntologyIdentifier', ontologyIdentifier, ...
                    'synonym', synonym);
                
                [metadataInstance, ~] = om.uiCreateNewInstance(newSpecies);
                if ~isempty(metadataInstance)
                    wasSuccess = true;
                end
            end
        end
    end

    methods (Access = protected)
        function validateMetadataType(obj, value) %#ok<INUSD>
            assert(value == openminds.enum.Types.Species)
        end
    end
end