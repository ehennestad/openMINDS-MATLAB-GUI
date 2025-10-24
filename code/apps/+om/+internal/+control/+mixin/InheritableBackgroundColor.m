classdef InheritableBackgroundColor < handle

    properties (Access = private)
        BindablePropertyListener event.listener
        LinkObject
    end

    methods (Access = protected)
        function activateBackgroundColorInheritance(comp)
            isValidComponent = isa(comp, 'matlab.ui.componentcontainer.ComponentContainer');

            assert(isValidComponent, 'This method can only be applied to "ComponentContainer" objects.')

            if isempty(comp.BindablePropertyListener)
                comp.BindablePropertyListener = listener(comp.Parent, ...
                    'BindablePropertyChanged', @comp.onParentPropertyChanged);

                comp.updateBackgroundColor()
            end
        end

        function deactivateBackgroundColorInheritance(comp)
            delete(comp.BindablePropertyListener)
            comp.BindablePropertyListener = event.listener.empty;
        end

        function addBackgroundColorLinkTargets(comp, target)
            if isempty(comp.LinkObject)
                comp.LinkObject = linkprop([comp, target], 'BackgroundColor');
            else
                comp.LinkObject.addtarget(target)
            end
            comp.updateBackgroundColor()
        end

        function removeBackgroundColorLinkTargets(comp, target)
            if isempty(comp.LinkObject)
                error('This component does not have a property link');
            else
                comp.LinkObject.removetarget(target)
            end
        end
    end

    methods (Access = private)
        function onParentPropertyChanged(comp, ~, evt)
            if isa(comp.Parent, 'matlab.ui.Figure')
                backgroundColorPropertyName = "Color";
            else
                backgroundColorPropertyName = "BackgroundColor";
            end
            if strcmp(evt.Property, backgroundColorPropertyName)
                comp.updateBackgroundColor()
            end
        end

        function updateBackgroundColor(comp)
            if isa(comp.Parent, 'matlab.ui.Figure') %#ok<*MCNPN>
                backgroundColor = comp.Parent.Color;
            else
                if isprop(comp.Parent, 'BackgroundColor')
                    backgroundColor = comp.Parent.BackgroundColor;
                else
                    S = warning('off', 'backtrace');
                    warning('Could not detect background color.')
                    warning(S);
                end
            end
            comp.BackgroundColor = backgroundColor; %#ok<*MCNPR>
        end
    end
end
