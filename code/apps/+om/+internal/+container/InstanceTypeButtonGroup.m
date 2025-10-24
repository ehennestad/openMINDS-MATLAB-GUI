classdef InstanceTypeButtonGroup < om.internal.abstract.TypeSelector

    properties (Dependent)
        Layout
        BackgroundColor
    end

    properties (Access = private)
        UIButtons  (1,:) matlab.ui.control.StateButton
        UIGridLayout matlab.ui.container.GridLayout
    end

    properties (Access = protected)
        UIComponent
    end

    methods %Set/get
        function value = get.Layout(comp)
            value = comp.UIGridLayout.Layout;
        end
        function set.Layout(comp, value)
            comp.UIGridLayout.Layout = value;
        end

        function value = get.BackgroundColor(comp)
            value = comp.UIGridLayout.BackgroundColor;
        end
        function set.BackgroundColor(comp, value)
            comp.UIGridLayout.BackgroundColor = value;
        end
    end

    methods (Access = protected) % Implement abstract methods
        function createComponent(comp)
            comp.createGridLayout
            comp.createButtons()
        end

        function updateSelectedTypeInComponent(comp)

            idx = find(strcmp({comp.UIButtons.Text}, comp.SelectedType));

            % Update button states if the selected type is not toggled.
            if ~comp.UIButtons(idx).Value
                [comp.UIButtons(:).Value] = deal(false);
                comp.UIButtons(idx).Value = 1;
            end
        end

        function onSelectedTypeChangedInComponent(comp, src, evt)
            comp.onTypeSelectorButtonPushed(src, evt)
        end
    end

    methods (Access = private)

        function createGridLayout(comp)

            availableTypes = comp.Types;
            N = numel(availableTypes);

            % Create a grid layout with 1 row and N columns
            comp.UIGridLayout = uigridlayout(comp.Parent, [1, N]);
            comp.UIGridLayout.Padding = 0;
        end

        function createButtons(comp)

            % Loop to create buttons in each cell
            for i = 1:numel(comp.Types)
                typeLabel = string(comp.Types(i));

                btn = uibutton(comp.UIGridLayout, "state", "Text", typeLabel);
                btn.Tag = comp.Types(i).ClassName;

                btn.ValueChangedFcn = @comp.privateComponentCallback;

                % Set the button layout to the i-th column
                btn.Layout.Column = i;
                btn.Layout.Row = 1;

                comp.UIButtons(i) = btn;
            end
            comp.UIButtons(1).Value = true;
        end
    end

    methods (Access = private)

        function onTypeSelectorButtonPushed(comp, src, ~)

            % Loop through all buttons to toggle them off except the clicked one
            for i = 1:length(comp.UIButtons)
                if comp.UIButtons(i) ~= src
                    comp.UIButtons(i).Value = false;
                end
            end

            % Toggle the clicked button
            src.Value = true;

            comp.SelectedType = src.Text;
        end
    end
end
