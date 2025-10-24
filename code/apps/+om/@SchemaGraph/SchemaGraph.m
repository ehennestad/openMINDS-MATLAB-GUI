classdef SchemaGraph < handle
%SchemaGraph This object represents the graph relationships for all schemas
%that are part of an openMINDS model.
    
% Todo: Why this class and not just a digraph? The digraph only contains the
% node as character vectors, this class adds the name of node properties
% and edge information (i.e what properties link two schemas together...)



    properties
        Modules = {'core'}
    end
    
    properties (Access = private)
        DirectedGraph
    end
    

    methods

        function obj = SchemaGraph()



        end

        function incomingLinks = getIncomingLinks(obj, schemaName)
            
        end

        function outgoingLinks = getOutgoingLinks(obj, schemaName)
            
        end

    end
end