classdef TableContextMenu < handle & matlab.mixin.SetGet

    properties
        DeleteItemFcn
    end

    properties (Access = private)
        UIFigure
        UIContextMenu

        UIMenuItemDeleteItem
    end

    methods
        function [obj, uiContextMenu] = TableContextMenu(hFigure, nvPairs)
        % TableContextMenu - Create a TableContextMenu instance
            arguments
                hFigure (1,1) matlab.ui.Figure
                nvPairs.?om.TableContextMenu
            end

            obj.set(nvPairs)

            obj.UIContextMenu = uicontextmenu(hFigure);
            obj.createMenuItems()
            obj.assignMenuItemCallbacks()

            if ~nargout
                clear obj
            end

            if nargout == 2
                uiContextMenu = obj.UIContextMenu;
            end
        end
    end

    methods
        function set.DeleteItemFcn(obj, value)
            obj.DeleteItemFcn = value;
            obj.postSetDeleteItemFcn()
        end
    end

    methods (Access = private)
        function createMenuItems(obj)

            obj.UIMenuItemDeleteItem = uimenu(obj.UIContextMenu, ...
                "Text", "Delete instance");
        end

        function assignMenuItemCallbacks(obj)
            obj.UIMenuItemDeleteItem.Callback = obj.DeleteItemFcn;
        end
    end

    % Property post set methods
    methods (Access = private)
        function postSetDeleteItemFcn(obj)
            obj.UIMenuItemDeleteItem.Callback = obj.DeleteItemFcn;
        end
    end
end
