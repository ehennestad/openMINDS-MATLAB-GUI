classdef GraphUpdatedEventData < event.EventData
    % GraphUpdatedEventData Event data for graph update notifications
    %
    % This class provides information about what changed in the graph
    % to enable incremental updates instead of full rebuilds
    
    properties
        UpdateType string % 'NODE_LABEL_CHANGED', 'NODE_ADDED', 'NODE_REMOVED', 'EDGES_CHANGED', 'FULL_REBUILD'
        InstanceId string % ID of the affected instance
        NodeIndex double  % Index of the affected node in graph
        AdditionalData    % Any additional data specific to the update type
    end
    
    methods
        function obj = GraphUpdatedEventData(updateType, instanceId, nodeIndex, additionalData)
            arguments
                updateType string
                instanceId string = ""
                nodeIndex double = []
                additionalData = []
            end
            obj.UpdateType = updateType;
            obj.InstanceId = instanceId;
            obj.NodeIndex = nodeIndex;
            obj.AdditionalData = additionalData;
        end
    end
end
