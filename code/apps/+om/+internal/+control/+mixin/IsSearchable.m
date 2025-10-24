classdef IsSearchable < handle

    % Assign ValueChangingCallback
    % Needs a private store of items.

    properties (Access = private)
        ItemsStore
        ItemsDataStore
    end

    methods (Access = protected)

        function filterDropdown(comp, searchString) %#ok<INUSD>
        end
    end
end
