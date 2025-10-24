classdef SchemaGraph < handle
%SchemaGraph This object represents the graph relationships for all schemas
%that are part of an openMINDS module.
    
% Todo: Why this class and not just a digraph? The digraph only contains the
% node as character vectors, this class adds the name of node properties
% and edge information (i.e what properties link two schemas together...)

    properties
        Modules = {'core'}
    end
    
    properties (Access = private)
        DirectedGraph (1,1) digraph = digraph
        EdgeProperties table  % Store property names for each edge
    end
    
    methods
        function obj = SchemaGraph(modules)
            % Constructor - generate graph for specified modules
            if nargin > 0
                obj.Modules = modules;
            end
            obj.buildGraph();
        end
        
        function buildGraph(obj)
            % Build the directed graph from schema definitions
            [sources, targets, edgeNames] = deal(cell(0,1));
            
            for i = 1:numel(obj.Modules)
                module = openminds.enum.Modules(obj.Modules{i});
                [G, edges] = om.internal.graph.generateGraph(module);
                
                % Accumulate sources, targets, and edge names
                % (merge graphs from multiple modules)
                sources = [sources; G.Edges.EndNodes(:,1)]; %#ok<AGROW>
                targets = [targets; G.Edges.EndNodes(:,2)]; %#ok<AGROW>
                edgeNames = [edgeNames; edges(:)]; %#ok<AGROW>
            end
            
            obj.DirectedGraph = digraph(sources, targets);
            obj.EdgeProperties = table(sources, targets, edgeNames, ...
                'VariableNames', {'Source', 'Target', 'PropertyName'});
        end
        
        function incomingLinks = getIncomingLinks(obj, typeName)
            % Get all schemas that link TO this typeName
            % Returns struct with source schema and property name
            edges = obj.DirectedGraph.inedges(typeName);
            incomingLinks = struct('Source', {}, 'PropertyName', {});
            
            for i = 1:numel(edges)
                endNodes = obj.DirectedGraph.Edges.EndNodes(edges(i), :);
                incomingLinks(i).Source = endNodes{1};
                incomingLinks(i).PropertyName = obj.EdgeProperties.PropertyName{edges(i)};
            end
        end
        
        function outgoingLinks = getOutgoingLinks(obj, typeName)
            % Get all schemas that this typeName links TO
            % Returns struct with target schema and property name
            edges = obj.DirectedGraph.outedges(typeName);
            outgoingLinks = struct('Target', {}, 'PropertyName', {});
            
            for i = 1:numel(edges)
                endNodes = obj.DirectedGraph.Edges.EndNodes(edges(i), :);
                outgoingLinks(i).Target = endNodes{2};
                outgoingLinks(i).PropertyName = obj.EdgeProperties.PropertyName{edges(i)};
            end
        end
    end
end
