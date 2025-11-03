classdef ListBoxLegacy < handle
%ListBox Listbox widget

    % Todo:
    %   [ ] Add facility for adding/removing items or replacing full list of items 

    properties
        % Whether single or multiple items in the list can be selected
        SelectionMode char {mustBeMember(SelectionMode, {'single', 'multiple'})} = 'multiple'
    end

    properties
        Items               % List (cell array) of items to display
        SelectionChangedFcn % Function handle to invoke when selected item changes
    end

    properties (Access = private)
        Name % List of names for each list item
        Icon % List of icons for each list item
    end

    properties % Appearance
        FontName = 'helvetica';
    end

    properties (SetAccess = private)
        Panel
        Buttons (1,:) uim.control.Button_
        ButtonCollection uim.widget.toolbar_
    end

    properties (Dependent)
        SelectedItems
    end

    properties (Access = private)
        SelectedButtons
    end

%     properties (Constant, Hidden = true) % Move to appwindow superclass
%         ICONS = uim.style.iconSet(structeditor.App.getIconPath)
%     end

    methods
        function obj = ListBox(hPanel, items)

            obj.Items = items;

            if isa(items, 'cell')
                obj.Name = items;
                obj.Icon = cell(size(obj.Name));
            elseif isa(items, 'struct')
                obj.Name = items.Name;
                obj.Icon = items.Icon;
            end

            buttonWidth = 160;
            xPad = 2;

            obj.Panel = hPanel;

            hToolbar = uim.widget.toolbar_(obj.Panel, 'Location', 'northwest', ...
                'Margin', [0,0,0,10],'ComponentAlignment', 'top', ...
                'BackgroundAlpha', 0, 'IsFixedSize', [true, false], ...
                'NewButtonSize', [buttonWidth, 25], 'Padding', [0,10,0,10], ...
                'Spacing', 0);

            buttonConfig = {'FontSize', 15, 'FontName', obj.FontName, ...
                'Padding', [xPad,2,xPad,2], 'CornerRadius', 0, ...
                'Mode', 'togglebutton', 'Style', uim.style.tabButton, ...
                'IconSize', [12,12], 'IconTextSpacing', 7};

            % Bug with toolbar so buttons are created from the bottom up
            counter = 0;
            for i = numel(obj.Name):-1:1
                counter = counter+1;

                thisName = obj.Name{i};
                thisIcon = obj.Icon{i};

%                 if any(strcmpi(obj.ICONS.iconNames, obj.Name{i}) )
%                     icon = obj.ICONS.(lower(obj.Name{i}));
%                 else
%                     icon = obj.ICONS.default;
%                 end

                obj.Buttons(counter) = hToolbar.addButton(...
                    'Text', om.internal.strutil.varname2label(thisName), 'Icon', thisIcon, ...
                    'Callback', @(s,e,n) obj.onListButtonPressed(s,e,i), ...
                    'Tag', thisName, buttonConfig{:} );
                if i == 1
                    obj.Buttons(counter).Value = true;
                end
            end

            obj.ButtonCollection = hToolbar;
            hToolbar.Location = 'northwest';
        end

        function delete(obj)
            delete(obj.ButtonCollection)
        end
    end

    methods % Set/get
        function set.SelectedItems(obj, newValue)
            % Check selection mode, i.e single, multiple

            obj.updateSelectedItems(newValue)
        end

        function selectedItems = get.SelectedItems(obj)
            selectedItems = {obj.SelectedButtons.Text};
        end
    end

    methods (Access = private)

        function onListButtonPressed(obj, src, evt, idx) %#ok<INUSD>

            % Todo: Why is index needed as input

            triggerCallback = false;
            oldSelection = {obj.SelectedButtons.Tag};
            % disp(evt.Source.SelectionType)
            switch evt.Source.SelectionType
                case 'normal'
                    % Clicked button which is already selected
                    if isequal(obj.SelectedButtons, src)
                        src.Value = true;
                        return
                    end

                    % Make sure other buttons are unselected
                    if ~isempty(obj.SelectedButtons)
                        for i = 1:numel(obj.SelectedButtons)
                            if isequal(obj.SelectedButtons(i), src)
                                obj.SelectedButtons(i).Value = true;
                            else
                                obj.SelectedButtons(i).Value = false;
                                triggerCallback = true;
                            end
                        end
                    end

                    obj.SelectedButtons = src;

                case 'extend'

                    if any(obj.SelectedButtons == src)
                        src.Value = true;
                        return
                    else
                        obj.SelectedButtons = [obj.SelectedButtons, src];
                        triggerCallback = true;
                    end

                case 'open'
                    if isequal(obj.SelectedButtons, src)
                        src.Value = true;
                        triggerCallback = true;
                    end
            end

            newSelection = {obj.SelectedButtons.Tag};

            % buttonNames = {obj.SelectedButtons.Text};
            % fprintf('Selected buttons: %s\n', strjoin(buttonNames, ', '))

            % Call the SelectionChangedFcn if present...
            if ~isempty(obj.SelectionChangedFcn) && triggerCallback
                % disp('Selection Changed')

                evt = om.gui.event.ItemSelectionEventData(oldSelection, newSelection);
                obj.SelectionChangedFcn(obj, evt)
            end

            % Notify listeners.
            % - What listeners?
        end

        function updateSelectedItems(obj, newSelection)
        %updateSelectedItems Programmatic entry point for setting items

            buttonNames = {obj.Buttons.Text};

            if isempty(obj.SelectedButtons)
                oldSelection = {};
            else
                oldSelection = {obj.SelectedButtons.Tag};
            end

            obj.SelectedButtons(:) = [];

            for i = 1:numel(obj.Buttons)
                obj.Buttons(i).Value = false;
            end

            if isa(newSelection, 'char'); newSelection = {newSelection}; end

            newSelection = cellfun(@(c) om.internal.strutil.varname2label(c), newSelection, 'UniformOutput', false);

            for i = 1:numel(newSelection)
                isSelectedButton = strcmp(buttonNames, newSelection{i});
                if any(isSelectedButton)
                    hButton = obj.Buttons(isSelectedButton);
                    hButton.Value = true;
                    obj.SelectedButtons = [obj.SelectedButtons, hButton];
                end
            end

            % Call the SelectionChangedFcn if preset...
            if ~isempty(obj.SelectionChangedFcn)
                % evt = event.EventData();
                evt = om.gui.event.ItemSelectionEventData(oldSelection, newSelection);
                obj.SelectionChangedFcn(obj, evt)
            end
        end
    end
end
