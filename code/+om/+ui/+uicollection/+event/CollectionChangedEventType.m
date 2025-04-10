classdef CollectionChangedEventType < handle

    enumeration
        INSTANCE_ADDED('InstanceAdded')
        INSTANCE_REMOVED('InstanceRemoved')
        INSTANCE_MODIFIED('InstanceModified')
    end

    properties (SetAccess=immutable)
        Name = '' %The user viewable/settable name for this column format
    end
    
    methods
        function obj = CollectionChangedEventType(eventType)
            obj.Name = eventType;
        end
    end
end
