classdef InteractiveOpenMINDSPlot < handle
    % InteractiveOpenMINDSPlot Interactive visualization of openMINDS metadata graphs
    %
    % Usage:
    %   % Basic usage
    %   plot = InteractiveOpenMINDSPlot(graphObj, hAxes);
    %
    %   % With UICollection for incremental updates
    %   uiCollection = om.ui.UICollection();
    %   plot = InteractiveOpenMINDSPlot(uiCollection.graph, hAxes);
    %   plot.attachUICollection(uiCollection);
    %   % Now when instances are modified, the plot updates incrementally
    %
    % [ ] Mouseover effects. Hand, magnify node and label
    % [ ] Custom text labels
    % [ ] Node Doubleclick Action
    % [ ] Add methods for plotting subgraps? Or should that be a separate
    %     panel in the main app for plotting subgraphs?

    % Todo:
    % Add active boolean that can be turned on and off from external gui
    % Deactivate figure mouse listener if this plot is not active.

    properties
         ColorMap = 'viridis'
         ShowNodeLabels
         ShowEdgeLabels
         Layout (1,1) string = "auto"
         MarkerSize = 14
    end

    properties (Access = protected) % data
        DirectedGraph
        UICollection % Reference to the UICollection for listening to events
    end

    properties (Access = protected) % graphical
        Axes matlab.graphics.axis.Axes
        GraphPlot matlab.graphics.chart.primitive.GraphPlot
        NodeTransporter GraphNodeTransporter
        PointerManager
        DataTip
        ActiveNode
    end

    properties (Access = private)
        IsMouseInGraph (1,1) logical = false
        IsMouseButtonDown (1,1) logical = false
        MouseReleaseListener event.listener
        GraphUpdateListener event.listener
        IsUpdateEnabled (1,1) logical = true  % Controls whether graph updates are processed
        IsGraphDirty (1,1) logical = false     % Tracks if graph has pending updates
    end

    properties (Access = protected)
        MouseMotionListener event.listener
    end

    methods
        function obj = InteractiveOpenMINDSPlot(graphObj, hAxes, ~)

            obj.DirectedGraph = graphObj;

            if nargin >= 2
                obj.Axes = hAxes;
            else
                f = figure('MenuBar', 'none');
                obj.Axes = axes(f, 'Position', [0.05,0.05,0.9,0.9]);
            end

            obj.Axes.YDir = 'normal';
            hFigure = ancestor(obj.Axes, 'figure');

            %--- Install pointer manager on the figure
            iptPointerManager(hFigure,'enable');

            obj.updateGraph(graphObj)

            obj.PointerManager = uim.interface.pointerManager(hFigure, ...
                obj.Axes, {'zoomIn', 'zoomOut', 'pan'});
            addlistener(hFigure, 'WindowKeyPress', @obj.keyPress);
           
            % Does not work for uifigure
            % obj.MouseMotionListener = listener(hFigure, "WindowMouseMotion", ...
            %     @obj.onWindowMouseMotion);
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

            if isempty(obj.DirectedGraph.Nodes)
                return
            end

            if ~obj.IsUpdateEnabled
                obj.IsGraphDirty = true;
                return
            end

            delete( obj.GraphPlot )
            hold(obj.Axes, 'off')

            % obj.DirectedGraph.Nodes.Name = arrayfun(@(x) num2str(x), 1:height(obj.DirectedGraph.Nodes), 'UniformOutput', false)';
            % obj.GraphPlot = plot(obj.Axes, graphObj, 'Layout', 'force');
            obj.GraphPlot = plot(obj.Axes, obj.DirectedGraph, 'Layout', obj.Layout);
            % obj.GraphPlot.NodeLabel = obj.DirectedGraph.Nodes.Name;
            % obj.GraphPlot.EdgeLabel = e;

            obj.GraphPlot.NodeLabel = [];
            numNodes = obj.DirectedGraph.numnodes;
            colors = colormap(obj.Axes, obj.ColorMap);

            randIdx = round(randperm(numNodes, numNodes)/numNodes*256);

            nodeIds = obj.DirectedGraph.Nodes.Name;
            % isInstances = ~startsWith(nodeIds, 'https'); Todo: Remove?

            nodeTypes = obj.DirectedGraph.Nodes.Type;

            uniqueInstanceTypes = unique(nodeTypes);
            uniqueIdx = round(linspace(1,256,numel(uniqueInstanceTypes)));

            for i = 1:numel(uniqueInstanceTypes)
                isThisInstanceType = strcmp(nodeTypes, uniqueInstanceTypes{i});
                randIdx(isThisInstanceType) = uniqueIdx(i);
            end

            obj.GraphPlot.NodeColor = colors(randIdx, :);

            obj.GraphPlot.MarkerSize = obj.MarkerSize;
            obj.GraphPlot.LineWidth = 1;
            obj.GraphPlot.EdgeColor = ones(1, 3)*0.6;

            hold(obj.Axes, 'on')
            obj.Axes.XLim = obj.Axes.XLim;
            obj.Axes.YLim = obj.Axes.YLim;
            % obj.Axes.Units = 'pixel';

            obj.GraphPlot.NodeFontName = 'avenir';
            obj.GraphPlot.NodeFontSize = 10;
            obj.GraphPlot.NodeLabelColor = [0.2,0.2,0.2];
            obj.GraphPlot.ArrowSize = 6;
            obj.GraphPlot.EdgeAlpha = 0.7;

            obj.plotMouseOverElements()

            obj.NodeTransporter = GraphNodeTransporter(obj.Axes);
            obj.NodeTransporter.ActiveNodeMarker = obj.ActiveNode;
            obj.NodeTransporter.NodeDataTip = obj.DataTip;

            obj.GraphPlot.ButtonDownFcn = @obj.onMousePressedInGraph;
            obj.addPointerBehaviorToGraph()
        end

        function keyPress(obj, ~, event)
            wasCaptured = obj.PointerManager.onKeyPress([], event);
        end

        function attachUICollection(obj, uiCollection)
            % attachUICollection Connect to a UICollection to receive graph update events
            %
            % This enables incremental graph updates instead of full rebuilds
            
            obj.UICollection = uiCollection;
            
            % Update DirectedGraph to reference the UICollection's graph
            obj.DirectedGraph = uiCollection.graph;
            
            % Clean up old listener if it exists
            if ~isempty(obj.GraphUpdateListener) && isvalid(obj.GraphUpdateListener)
                delete(obj.GraphUpdateListener);
            end
            
            % Listen to GraphUpdated events
            obj.GraphUpdateListener = addlistener(uiCollection, 'GraphUpdated', ...
                @obj.onGraphUpdated);
        end

        function enableUpdates(obj)
            % enableUpdates Enable immediate graph updates
            obj.IsUpdateEnabled = true;
        end

        function disableUpdates(obj)
            % disableUpdates Disable immediate graph updates (marks as dirty instead)
            obj.IsUpdateEnabled = false;
        end

        function updateIfDirty(obj)
            % updateIfDirty Update the graph if it has pending changes
            if obj.IsGraphDirty
                obj.IsUpdateEnabled = true;  % Temporarily enable updates
                obj.updateGraph();           % Force a full update
                obj.IsGraphDirty = false;    % Mark as clean
            end
        end

        function onGraphUpdated(obj, ~, evtData)
            % onGraphUpdated Handle incremental graph updates
            %
            % This method updates only what changed instead of rebuilding everything
            
            % Skip updates if not enabled (e.g., graph tab not visible)
            if ~obj.IsUpdateEnabled
                obj.IsGraphDirty = true;
                return
            end
            
            % Get the current graph from UICollection (digraph is a value class)
            % IMPORTANT: Always update DirectedGraph to get the latest graph state
            if ~isempty(obj.UICollection)
                currentGraph = obj.UICollection.graph;
                obj.DirectedGraph = currentGraph; % Update the local copy
            else
                currentGraph = obj.DirectedGraph;
            end
            
            % Mark as clean since we're processing the update
            obj.IsGraphDirty = false;
            
            switch evtData.UpdateType
                case 'NODE_LABEL_CHANGED'
                    % The DirectedGraph has been updated, so mouseover will now show correct label
                    % Update only the DataTip if this is the active node
                    if ~isempty(evtData.NodeIndex) && evtData.NodeIndex <= numnodes(currentGraph)
                        % Update the DataTip if this is the active node
                        if ~isempty(obj.ActiveNode.XData) && ~isnan(obj.ActiveNode.XData) && ...
                           obj.ActiveNode.XData == obj.GraphPlot.XData(evtData.NodeIndex) && ...
                           obj.ActiveNode.YData == obj.GraphPlot.YData(evtData.NodeIndex)
                            obj.DataTip.String = sprintf('%s (%s)', ...
                                currentGraph.Nodes.Label{evtData.NodeIndex}, ...
                                currentGraph.Nodes.Type{evtData.NodeIndex});
                        end
                    end
                    
                case 'FULL_REBUILD'
                    % Full rebuild is still needed in some cases
                    obj.updateGraph();
                    
                otherwise
                    % For other update types, do a full rebuild for now
                    % Can be optimized later for specific cases
                    obj.updateGraph();
            end
        end
    end

    methods (Access = private)
        function plotMouseOverElements(obj)
            obj.ActiveNode = plot(obj.Axes, nan, nan, 'o', ...
                'HitTest', 'off', ...
                'PickableParts', 'none', ...
                'Marker', 'o', ...
                'MarkerSize', obj.MarkerSize+1, ...
                'MarkerFaceColor', 'w');
            uistack(obj.ActiveNode, 'top');

            obj.DataTip = text(obj.Axes, 0,0,'', ...
                'FontSize',14, ...
                'HitTest', 'off', ...
                'PickableParts', 'none', ...
                'Interpreter', 'none');
            uistack(obj.DataTip, 'top');
        end
    end

    methods (Access = private) % Interactive callback methods
        function onWindowMouseMotion(obj, src, ~)
            h = hittest();
            if isa(h, 'matlab.graphics.chart.primitive.GraphPlot')
                point = src.CurrentPoint;
                obj.updateGraphNodeDataTip(point)
            else
                obj.hideGraphNodeDataTip(src)
            end
        end

        function onMousePressedInGraph(obj, src, evt)
            obj.IsMouseButtonDown = true;

            obj.NodeTransporter.startDrag(src, evt);
            
            hFigure = ancestor(obj.Axes, 'figure');
            obj.MouseReleaseListener = listener(hFigure, ...
                'WindowMouseRelease', @(src, event) obj.onMouseReleasedFromGraph);
        end

        function onMouseReleasedFromGraph(obj)
            obj.IsMouseButtonDown = false;

            if ~isempty(obj.MouseReleaseListener)
                if isvalid(obj.MouseReleaseListener)
                    delete(obj.MouseReleaseListener)
                end
                obj.MouseReleaseListener = event.listener.empty;
            end
        end

        function onMouseMotionInGraph(obj, src, ~)
            set(src,'Pointer','hand')

            point = src.CurrentPoint;
            obj.updateGraphNodeDataTip(point)
        end

        function onLayoutPropertySet(obj)
            if ~isempty(obj.GraphPlot)
                obj.updateGraph();
            end
        end
    end

    methods (Access = private)
        function updateGraphNodeDataTip(obj, point)
            x = point(1); y = point(2);

            axesPosition = getpixelposition(obj.Axes,true);
            x = x - axesPosition(1);
            y = y - axesPosition(2);

            numAxUnitPerPixelX = diff(obj.Axes.XLim) / axesPosition(3);
            numAxUnitPerPixelY = diff(obj.Axes.YLim) / axesPosition(4);

            xAxesUnit = x * numAxUnitPerPixelX + obj.Axes.XLim(1) ;
            yAxesUnit = y * numAxUnitPerPixelY + obj.Axes.YLim(1);

            % Find Node Index
            graphObj = obj.GraphPlot;
            % graphObj.XData
            deltaX = diff(obj.Axes.XLim) / axesPosition(3) * 10;
            deltaY = diff(obj.Axes.YLim) / axesPosition(4) * 10;

            isOnX = abs( graphObj.XData - xAxesUnit ) < deltaX;
            isOnY = abs( graphObj.YData - yAxesUnit ) < deltaY;

            nodeIdx = find( isOnX & isOnY, 1, 'first');

            if ~isempty(nodeIdx)
                % disp(obj.DirectedGraph.Nodes.Name(nodeIdx))
                %obj.DataTip.Position = [xAxesUnit, yAxesUnit];
                obj.DataTip.Position = [graphObj.XData(nodeIdx), graphObj.YData(nodeIdx)];
                obj.DataTip.String = sprintf('%s (%s)', ...
                    obj.DirectedGraph.Nodes.Label{nodeIdx}, ...
                    obj.DirectedGraph.Nodes.Type{nodeIdx});
                obj.ActiveNode.XData = graphObj.XData(nodeIdx);
                obj.ActiveNode.YData = graphObj.YData(nodeIdx);
            else
                obj.DataTip.String = '';
                obj.ActiveNode.XData = nan;
                obj.ActiveNode.YData = nan;
            end
        end

        function hideGraphNodeDataTip(obj, hFigure)
            if obj.IsMouseButtonDown 
                return
            end
            obj.DataTip.String = '';
            obj.ActiveNode.XData = nan;
            obj.ActiveNode.YData = nan;
            set(hFigure,'Pointer','arrow')
        end

        function addPointerBehaviorToGraph(obj)
        % addPointerBehaviorToGraph - Attach pointer behavior to graph object
            if ~isempty(obj.GraphPlot)
                pb.enterFcn    = @(fig, h) obj.onMouseMotionInGraph(fig, h);
                pb.exitFcn     = @(fig, h) obj.hideGraphNodeDataTip(fig);
                pb.traverseFcn = @(fig, h) obj.onMouseMotionInGraph(fig, h);
                iptSetPointerBehavior(obj.GraphPlot, pb);        
            end
        end
    end
end
