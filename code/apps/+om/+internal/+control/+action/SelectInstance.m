classdef SelectInstance < om.internal.abstract.Action

    properties (Constant)
        Name = "Select Instance"
        Description = "Placeholder for dropdown. Prompt user to select an instance, and returns an empty instance if selected"
    end

    properties (Constant, Access=protected)
        LabelTemplate = "*Select a instance*"
    end

    methods
        function [wasSuccess, itemsData] = execute(obj)

        end
    end
end