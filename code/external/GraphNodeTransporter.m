classdef GraphNodeTransporter < applify.gobjectTransporter


    properties
        CurrentNodeIndex = []
        ActiveNodeMarker = []
        NodeDataTip = []
    end

    methods
        function startDrag(obj, src, event)

            % NB: Call this before assigning moveObject callback. Update
            % coordinates callback is activated in the moveObject
            % function..
            x = event.IntersectionPoint(1);
            y = event.IntersectionPoint(2);
            obj.previousMousePointAxes = [x, y];

            % Find Node Index
            graphObj = src;
            
            axesPosition = getpixelposition(obj.hAxes);
            deltaX = diff(obj.hAxes.XLim) / axesPosition(3) * 10;
            deltaY = diff(obj.hAxes.YLim) / axesPosition(4) * 10;

            isOnX = abs( graphObj.XData - x ) < deltaX;
            isOnY = abs( graphObj.YData - y ) < deltaY;

            obj.CurrentNodeIndex = find( isOnX & isOnY, 1, 'first');
            if isempty(obj.CurrentNodeIndex); return; end
            
            obj.currentHandle = graphObj;
            obj.isMouseDown = true;

            el(1) = listener(obj.hFigure, 'WindowMouseMotion', @(src, event) obj.moveObject);
            el(2) = listener(obj.hFigure, 'WindowMouseRelease', @(src, event) obj.stopDrag);
            obj.WindowMouseMotionListener = el(1);
            obj.WindowMouseReleaseListener = el(2);
        end

        function moveObject(obj)
        %moveObject Execute when mouse is dragging a selected object    

            % Get current coordinates
            newMousePointAx = obj.hAxes.CurrentPoint(1, 1:2);
                        
            shift = newMousePointAx - obj.previousMousePointAxes;
            h = obj.currentHandle;
            i = obj.CurrentNodeIndex;

            h.XData(i) = h.XData(i) + shift(1);
            h.YData(i) = h.YData(i) + shift(2);

            if ~isempty(obj.ActiveNodeMarker)
                obj.ActiveNodeMarker.XData = obj.ActiveNodeMarker.XData + shift(1);
                obj.ActiveNodeMarker.YData = obj.ActiveNodeMarker.YData + shift(2);
            end
            if ~isempty(obj.NodeDataTip)
                obj.NodeDataTip.Position(1:2) = obj.NodeDataTip.Position(1:2) + shift;
            end

            obj.previousMousePointAxes = newMousePointAx;
        end

        function stopDrag(obj)
            obj.isMouseDown = false;
            obj.resetInteractiveFigureListeners()
        end
    end
end
