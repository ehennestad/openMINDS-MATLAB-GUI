classdef Action < handle
    
    properties (Abstract, Constant)
        Name (1,1) string
        Description (1,1) string
    end

    properties (Abstract, Constant, Access=protected)
        LabelTemplate (1,1) string
    end

    properties (Dependent)
        Label
    end

    properties
        % MetadataType - type of instance coupled to this action
        MetadataType (1,1) openminds.enum.Types = "None"
    end

    properties (GetAccess = protected)
        AncestorFigure matlab.ui.Figure
        ParentComponent
        %MetadataCollection
    end

    methods (Abstract)
        [wasSuccess, itemsData] = execute(obj)
    end

    methods (Access = protected)
        function validateMetadataType(obj, value) %#ok<INUSD>
            % Subclasses may override
        end
    end

    methods % Set/get
        function label = get.Label(obj)
            typeName = string(obj.MetadataType);

            % Get label from vocab
            typeLabel = openminds.internal.vocab.getSchemaLabelFromName(typeName);

            vowels = 'aeiouy';
            typeLabel = char(typeLabel);
            startsWithVowel = any( lower(typeLabel(1)) == vowels );
            
            label = obj.LabelTemplate;
            label = strrep(label, 'instance', sprintf('%s instance', lower(typeLabel)));
            if startsWithVowel
                % Replace indefinite article
                label = strrep(label, ' a ', ' an ');
            end

            %label = strrep(label, ' instances', '');
            %label = strrep(label, ' instance', '');
        end
    
        function set.MetadataType(obj, value)
            obj.validateMetadataType(value)
            obj.MetadataType = value;
        end
    end

    methods (Access = protected)
        function throwUiError(obj, errorMessage, errorTitle)
            if ~isempty(obj.AncestorFigure)                
                uialert(obj.AncestorFigure, errorMessage, errorTitle);
            else
                errordlg(errorMessage, errorTitle)
            end
        end
    end

end