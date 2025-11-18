classdef SearchableList < matlab.ui.componentcontainer.ComponentContainer
% SearchableList  Searchable dropdown backed by uihtml.
%
% Public Properties:
%   Items       : string array of options
%   Value       : currently selected value (string, must be in Items or "")
%   Placeholder : text shown when no selection
%
%   ValueChanged event with ValueChangedFcn callback.

    %% Public properties
    properties
        Items (:,1) string = string.empty(0,1)
        Value (1,1) string = ""
        Placeholder (1,1) string = "Select an option…"
    end

    %% Events
    events (HasCallbackProperty, NotifyAccess = protected)
        ValueChanged
    end

    %% Private internals
    properties (Access = private, Transient, NonCopyable)
        HTMLComponent matlab.ui.control.HTML
        ThemeListener event.listener
    end

    methods (Access = protected)
        function setup(comp)
            % Create uihtml and point to HTML file
            comp.HTMLComponent = uihtml(comp);
            comp.HTMLComponent.Position = [1 1 comp.Position(3:4)];

            htmlFile = fullfile(fileparts(mfilename("fullpath")), ...
                                "SearchableList.html");
            comp.HTMLComponent.HTMLSource = htmlFile;

            % Data round-trip
            comp.HTMLComponent.DataChangedFcn = ...
                @(src, evt) onHTMLDataChanged(comp, evt);
            
            % Set up theme listener
            setupThemeListener(comp);
        end

        function update(comp)
            % Keep uihtml aligned with our size and push state to HTML
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Position = [1 1 comp.Position(3:4)];
                comp.HTMLComponent.Data = buildDataStruct(comp);
            end
        end
    end
    
    methods
        function focus(comp)
            if isempty(comp.HTMLComponent) || ~isvalid(comp.HTMLComponent)
                return
            end
            
            % Send fresh data with focus command to avoid stale HTML values
            data = buildDataStruct(comp);
            data.command = 'focus';
            data.nonce = char(matlab.lang.internal.uuid());
            comp.HTMLComponent.Data = data;
        end

        function reset(comp)
            % Clear value and send reset command to HTML
            comp.Value = "";
            
            data = buildDataStruct(comp);
            data.command = "reset";
            data.nonce = char(matlab.lang.internal.uuid());
            comp.HTMLComponent.Data = data;
        end
    end


    methods (Access = private)
        function onHTMLDataChanged(comp, evt)
            data = evt.Data;
            if ~isstruct(data) || ~isfield(data, "action")
                return
            end
    
            action = string(data.action);
    
            % Use existing Value if none provided
            if isfield(data, "value")
                newValue = string(data.value);
            else
                newValue = comp.Value;
            end
    
            % Helper: update Value + fire event if changed
            function updateValueIfChanged()
                if newValue ~= comp.Value
                    oldValue = comp.Value;
                    comp.Value = newValue;
                    
                    % Create event data and notify
                    evtData = matlab.ui.eventdata.ValueChangedData(newValue, oldValue);
                    notify(comp, "ValueChanged", evtData);
                end
            end
    
            switch action
                case "select"
                    % Mouse selection (no implicit close)
                    updateValueIfChanged();
    
                case "accept"
                    % ENTER pressed: select highlighted and close
                    updateValueIfChanged();
                    comp.maybeResumeParentFigure();
    
                case "cancel"
                    % ESC pressed: cancel and close
                    % You can choose whether to clear Value or keep it.
                    % Here we keep the existing Value, just close the dialog.
                    comp.maybeResumeParentFigure();
    
                otherwise
                    % ignore other actions if you add them
            end
        end
    end

    methods (Access = protected)
        function theme = getTheme(comp)
            % Get the theme from parent figure
            f = ancestor(comp, "figure");
            if ~isempty(f) && isvalid(f) && isprop(f, "Theme") && ~isempty(f.Theme)
                theme = f.Theme.BaseColorStyle;
            else
                theme = 'light';  % Default to light theme
            end
        end
    end
    
    methods (Access = private)
        function data = buildDataStruct(comp)
            % Build standard data structure to send to HTML
            theme = getTheme(comp);
            data.options     = cellstr(comp.Items);
            data.value       = char(comp.Value);
            data.placeholder = char(comp.Placeholder);
            data.theme       = char(theme);
        end
        
        function maybeResumeParentFigure(comp)
            % [Unverified] This only does something if you use uiwait(fig)
            f = ancestor(comp, "figure");
            if ~isempty(f) && isvalid(f)
                % Guard WaitStatus to avoid errors if not waiting
                if isprop(f, "WaitStatus") && strcmpi(f.WaitStatus, "waiting")
                    uiresume(f);
                end
            end
        end
        
        function setupThemeListener(comp)
            % Listen for theme changes on parent figure
            f = ancestor(comp, "figure");
            if ~isempty(f) && isvalid(f) && isprop(f, "Theme") && ~isempty(f.Theme)
                comp.ThemeListener = addlistener(f, "Theme", "PostSet", ...
                    @(~,~) onThemeChanged(comp));
            end
        end
        
        function onThemeChanged(comp)
            % Update HTML component when theme changes
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                data = buildDataStruct(comp);
                data.nonce = char(matlab.lang.internal.uuid());
                comp.HTMLComponent.Data = data;
            end
        end
    end
end
