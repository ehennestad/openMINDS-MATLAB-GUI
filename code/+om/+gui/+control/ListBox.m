function obj = ListBox(hPanel, items)
% ListBox - Factory function to create version-appropriate ListBox component
%
%   obj = ListBox(hPanel, items) creates either a ListBoxModern or
%   ListBoxLegacy component based on the MATLAB version.
%
%   For MATLAB R2023a and later, creates a ListBoxModern using the native
%   uilistbox component. For older versions, creates a ListBoxLegacy using
%   the NANSEN graphics toolbar.
%
%   Inputs:
%       hPanel - Parent panel handle
%       items  - Cell array of strings for list items
%
%   Output:
%       obj - ListBox component (either ListBoxModern or ListBoxLegacy)

    if useModernComponents()
        obj = om.gui.control.ListBoxModern(hPanel, items);
    else
        obj = om.gui.control.ListBoxLegacy(hPanel, items);
    end
end

function tf = useModernComponents()
    % Check if we're running MATLAB R2023a or later
    tf = exist('isMATLABReleaseOlderThan', 'file') == 2 ...
        && ~isMATLABReleaseOlderThan("R2023a");
end
