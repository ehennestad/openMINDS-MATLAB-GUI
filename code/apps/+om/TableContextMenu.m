classdef TableContextMenu < handle & matlab.mixin.SetGet

    properties
        DeleteItemFcn
        ExportToWorkspaceFcn
        EditInstanceFcn
    end

    properties (Access = private)
        UIFigure
        UIContextMenu

        UIMenuItemDeleteItem
        UIMenuItemExportToWorkspace
        UIMenuItemEditInstance
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

        function set.ExportToWorkspaceFcn(obj, value)
            obj.ExportToWorkspaceFcn = value;
            obj.postSetExportToWorkspaceFcn()
        end

        function set.EditInstanceFcn(obj, value)
            obj.EditInstanceFcn = value;
            obj.postSetEditInstanceFcn()
        end
    end

    methods (Access = private)
        function createMenuItems(obj)
            obj.UIMenuItemEditInstance = uimenu(obj.UIContextMenu, ...
                "Text", "Edit instance");
            
            obj.UIMenuItemExportToWorkspace = uimenu(obj.UIContextMenu, ...
                "Text", "Export to workspace");

            obj.UIMenuItemDeleteItem = uimenu(obj.UIContextMenu, ...
                "Text", "Delete instance", "Separator", "on");
        end

        function assignMenuItemCallbacks(obj)
            obj.UIMenuItemEditInstance.Callback = obj.EditInstanceFcn;
            obj.UIMenuItemDeleteItem.Callback = obj.DeleteItemFcn;
            obj.UIMenuItemExportToWorkspace.Callback = obj.ExportToWorkspaceFcn;
        end
    end

    % Property post set methods
    methods (Access = private)
        function postSetDeleteItemFcn(obj)
            obj.UIMenuItemDeleteItem.Callback = obj.DeleteItemFcn;
        end

        function postSetExportToWorkspaceFcn(obj)
            obj.UIMenuItemExportToWorkspace.Callback = obj.ExportToWorkspaceFcn;
        end

        function postSetEditInstanceFcn(obj)
            obj.UIMenuItemEditInstance.Callback = obj.EditInstanceFcn;
        end
    end
end
