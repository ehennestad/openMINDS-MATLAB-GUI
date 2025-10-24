classdef InstanceDropDownOptions < handle

    properties (Constant, Access = private)
        DefaultActions = ["*Select a instance*", "*Create a new instance*", "*Download instances*"]
    end

    properties (SetAccess = private)
        MetadataType (1,1) string {om.internal.validator.mustBeTypeClassName} = missing
    end

    properties (SetAccess = private)
        MetadataCollection
        RemoteMetadataCollection
    end

    properties (AbortSet = true)
        % MetadataType - The metadata type which is currently active/selected 
        % in this component
        ActiveMetadataType (1,1) openminds.enum.Types = "None"
    end


    % Properties that corresponds with internal states
    properties (Access = private)
        % HasRemoteInstances - Boolean flag indicating whether dropdown is
        % populated with remote instances (instances from a remote metadata 
        % collection)
        HasRemoteInstances = false

        % AllowedTypes - List of openMINDS types which this dropdown
        % supports. Note, this is either a scalar or a list if the dropdown
        % represents a mixed type.
        AllowedTypes (1,:) openminds.enum.Types

        Actions (1,:) string
    end

    


end