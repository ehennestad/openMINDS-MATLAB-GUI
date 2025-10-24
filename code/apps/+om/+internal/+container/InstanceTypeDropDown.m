classdef InstanceTypeDropDown < om.internal.abstract.TypeSelector

    properties (Dependent)
        Layout
    end

    properties (Access = protected)
        UIComponent
    end

    methods %Set/get
        function value = get.Layout(comp)
            value = comp.UIComponent.Layout;
        end
        function set.Layout(comp, value)
            comp.UIComponent.Layout = value;
        end
    end

    methods (Access = protected) % Implement abstract methods
        function createComponent(comp)
            comp.createDropDown()
        end

        function updateSelectedTypeInComponent(comp)
            comp.UIComponent.Value = comp.SelectedType;
        end

        function onSelectedTypeChangedInComponent(comp, src, evt)
            comp.onDropDownValueChanged(src, evt)
        end
    end

    methods (Access = private)
        function createDropDown(comp)
            comp.UIComponent = uidropdown(comp.Parent);
            comp.UIComponent.Items = string([comp.Types.ClassName]);
            comp.UIComponent.ItemsData = string(comp.Types);
            comp.UIComponent.ValueChangedFcn = @comp.privateComponentCallback;
        end
    end

    methods (Access = private)

        function onDropDownValueChanged(comp, ~, evt)
            comp.SelectedType = evt.Value;
        end
    end
end
