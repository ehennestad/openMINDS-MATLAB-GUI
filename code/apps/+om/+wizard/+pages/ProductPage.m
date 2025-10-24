classdef ProductPage < wizard.abstract.Page

    properties (Constant)
        Name = 'Product'
        Title = "Select Research Product"
        Description = "Select a Research Product"
    end

    properties
        % DataModel ndi.dataset.gui.models.DatasetInfo
    end
    properties (Dependent)
        SelectedProduct
    end

    properties (SetAccess = ?wizard.WizardApp)
        PageData
    end

    properties (Access = private) % App components
        GridLayout
        DatasetWidgets om.wizard.pages.component.Product
    end

    methods
        function value = get.SelectedProduct(obj)
            value = obj.getPropertyValue("SelectedProduct");
        end
    end

    methods % Constructor
        function obj = ProductPage()
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
            if isempty(obj.DatasetWidgets.SelectedProduct) || isequal(obj.DatasetWidgets.SelectedProduct, "")
                error('openMINDS:NoResearchProductSelected', 'Please select a research product')
            end
        end

        function createComponents(obj)
            obj.GridLayout = uigridlayout(obj.UIPanel);
            obj.GridLayout.ColumnWidth = {'1x'};
            obj.GridLayout.RowHeight = {'1x'};
            obj.GridLayout.Padding = 0;

            obj.DatasetWidgets = om.wizard.pages.component.Product(obj.GridLayout);
        end
    end
end
