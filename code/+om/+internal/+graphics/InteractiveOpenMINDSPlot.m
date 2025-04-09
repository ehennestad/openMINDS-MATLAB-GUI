classdef InteractiveOpenMINDSPlot < handle

    %
    % [ ] Mouseover effects. Hand, magnify node and label
    % [ ] Custom text labels
    % [ ] Node Doubleclick Action
    % [ ] Add methods for plotting subgraps? Or should that be a separate
    %     panel in the main app for plotting subgraphs?

    properties
         ColorMap = 'viridis'
         ShowNodeLabels
         ShowEdgeLabels
         Layout (1,1) string = "auto"
    end

    properties (Access = protected) % data
        DirectedGraph
    end
   
    properties (Access = protected) % grahical
        Axes
        GraphPlot
        NodeTransporter
        PointerManager
    end

    methods 
        function obj = InteractiveOpenMINDSPlot(graphObj, hAxes, e)
            
            obj.DirectedGraph = graphObj;

            if nargin >= 2
                obj.Axes = hAxes;
            else
                f = figure('MenuBar', 'none');
                obj.Axes = axes(f, 'Position', [0.05,0.05,0.9,0.9]);
            end

            obj.updateGraph(graphObj)

            obj.GraphPlot.ButtonDownFcn = @(s,e) obj.NodeTransporter.startDrag(s,e);

            %obj.GraphPlot.EdgeLabel = e;
    
            obj.Axes.YDir = 'normal';
            hFigure = ancestor(obj.Axes, 'figure');
            obj.PointerManager = uim.interface.pointerManager(hFigure, ...
                obj.Axes, {'zoomIn', 'zoomOut', 'pan'});
            addlistener(hFigure, 'WindowKeyPress', @obj.keyPress);
            
            %obj.Axes.YDir = 'reverse';
        end 
    end

    methods % Set/Get
        function set.Layout(obj, newValue)
            obj.Layout = newValue;
            obj.onLayoutPropertySet()
        end
    end

    methods
        function updateGraph(obj, graphObj)
            if nargin >= 2
                obj.DirectedGraph = graphObj;
            end

            delete( obj.GraphPlot )        
            hold(obj.Axes, 'off')

            %obj.GraphPlot = plot(obj.Axes, graphObj, 'Layout', 'force');
            obj.GraphPlot = plot(obj.Axes, obj.DirectedGraph, 'Layout', obj.Layout);

            numNodes = obj.DirectedGraph.numnodes;
            colors = colormap(obj.ColorMap);
            
            randIdx = round(randperm(numNodes, numNodes)/numNodes*256);
    
            nodeIds = obj.DirectedGraph.Nodes.Name;
            isInstances = ~startsWith(nodeIds, 'https');
            
            uniqueInstanceTypes = unique(extractBefore(nodeIds(isInstances), "/"));
            uniqueIdx = linspace(1,256,numel(uniqueInstanceTypes));

            for i = 1:numel(uniqueInstanceTypes)
                isThisInstanceType = startsWith(nodeIds, uniqueInstanceTypes{i});
                randIdx(isThisInstanceType) = uniqueIdx(i);
            end

            obj.GraphPlot.NodeColor = colors(randIdx, :);
            
            obj.GraphPlot.MarkerSize = 10;
            obj.GraphPlot.LineWidth = 1;
            obj.GraphPlot.EdgeColor = ones(1, 3)*0.6;
            
            hold(obj.Axes, 'on')
            obj.Axes.XLim = obj.Axes.XLim;
            obj.Axes.YLim = obj.Axes.YLim;
            %obj.Axes.Units = 'pixel';

            obj.GraphPlot.NodeFontName = 'avenir';
            obj.GraphPlot.NodeFontSize = 10;
            obj.GraphPlot.NodeLabelColor = [0.2,0.2,0.2];
            
            obj.NodeTransporter = GraphNodeTransporter(obj.Axes);
            obj.GraphPlot.ButtonDownFcn = @(s,e) obj.NodeTransporter.startDrag(s,e);
        end

        function keyPress(obj, src, event)
            wasCaptured = obj.PointerManager.onKeyPress([], event);
        end
    end

    methods (Access = private)
        function onLayoutPropertySet(obj)
            if ~isempty(obj.GraphPlot)
                obj.updateGraph();
            end
        end
    end
end