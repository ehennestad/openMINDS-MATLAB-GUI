classdef CompletionPage < wizard.abstract.Page

    properties (Constant)
        Name = 'GoingFurther'
        Title = "Select Next Steps"
        Description = "What do you want to do next?"
    end

    properties
        % DataModel ndi.dataset.gui.models.DatasetInfo
    end
    properties (SetAccess = ?wizard.WizardApp)
        PageData
    end

    properties (Access = private) % App components
        GridLayout
        DatasetWidgets om.wizard.pages.component.NextSteps
    end

    methods % Constructor
        function obj = CompletionPage()
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

            obj.DatasetWidgets = om.wizard.pages.component.NextSteps(obj.GridLayout);
        end
    end
end
