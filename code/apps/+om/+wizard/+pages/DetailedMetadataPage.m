classdef DetailedMetadataPage < wizard.abstract.Page

    properties (Constant)
        Name = 'Detailed Metadata'
        Title = "Enter metadata details"
        Description = "Enter information for the following fields"
    end

    properties
        % DataModel ndi.dataset.gui.models.DatasetInfo
    end
    properties (SetAccess = ?wizard.WizardApp)
        PageData
    end

    properties (Access = public, Dependent)
    end

    properties (Access = private) % App components
        GridLayout
        DatasetWidgets
    end

    methods % Constructor
        function obj = DetailedMetadataPage()
            %obj.AppData = ndi.dataset.gui.models.DatasetInfo();
        end
    end

    methods (Access = protected)

        function setPropertyValue(obj, propertyName, propertyValue)
            if ~isempty(obj.PageData)
                obj.PageData.(propertyName) = propertyValue;
            end
            if obj.IsInitialized
                obj.DatasetWidgets.(propertyName) = propertyValue;
            end
        end

        function propertyValue = getPropertyValue(obj, propertyName)
            if obj.IsInitialized
                propertyValue = obj.DatasetWidgets.(propertyName);
            else
                if isprop(obj.PageData, propertyName)
                    propertyValue = obj.PageData.(propertyName);
                else
                    propertyValue = "";
                end
            end
        end

        function onPageEntered(obj)
            % Subclasses may override
        end

        function onPageExited(obj)
            % Subclasses may override
        end

        function createComponents(obj)
            obj.GridLayout = uigridlayout(obj.UIPanel);
            obj.GridLayout.ColumnWidth = {'1x'};
            obj.GridLayout.RowHeight = {'1x'};
            obj.GridLayout.Padding = 0;

            obj.UIPanel.Layout.Row = [1,3];

            page = obj.ParentApp.getPage("Select Research Product");
            productName = page.SelectedProduct;

            instance = feval( sprintf('openminds.core.%s', productName) );
            collection = openminds.Collection(instance);

            SNew = om.convert.toStruct( instance, collection );
            obj.DatasetWidgets = structeditor.UIControlContainer(obj.GridLayout, SNew);
        end
    end
end
