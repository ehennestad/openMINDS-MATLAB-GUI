classdef ItemSelectionEventData < event.EventData
    %ITEMSELECTIONEVENTDATA Summary of this class goes here
    %   Detailed explanation goes here

    properties
        OldSelection
        NewSelection
    end

    methods
        function obj = ItemSelectionEventData(oldSelection, newSelection)
            %ITEMSELECTIONEVENTDATA Construct an instance of this class
            %   Detailed explanation goes here
            obj.OldSelection = oldSelection;
            obj.NewSelection = newSelection;
        end
    end
end
