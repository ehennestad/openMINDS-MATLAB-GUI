function [G, edgeLabels] = generateGraph(module, optionals)
% GENERATEGRAPH Generates a directed graph of class relationships for a specified OpenMINDS module.
%
%   G = GENERATEGRAPH(moduleName) constructs a directed graph G where the nodes
%   represent classes from the specified OpenMINDS module, and the edges
%   represent the properties linking these classes.
%
%   [G, edgeLabels] = GENERATEGRAPH(moduleName) also returns edgeLabels, a cell
%   array of property names that define each edge in the graph G.
%
%   Inputs:
%       moduleName (string, optional) - The name of the OpenMINDS module to
%           generate the graph for.
%           Default: 'core'
%
%   Outputs:
%       G - A directed graph object (digraph) where each node corresponds to a
%           class and each edge corresponds to a property linking instances of
%           these classes.
%
%       edgeLabels (cell array of strings) - A cell array containing the names
%           of the properties that define the edges in the graph G.
%
%   Example:
%       G = generateGraph('metadata');
%       [G, edgeLabels] = generateGraph('controlledterms', true);
%
%   The function extracts class relationships by inspecting the properties of
%   classes within the specified openMINDS module and creates a directed graph
%   representing these relationships. Each node in the graph corresponds to a
%   class, and each edge represents a property that links an instance of the
%   source class to an instance of the target class.
%
%   See also: digraph

    % Save graph
    % Modify type classes to include incoming links/edges.

    arguments
        module (1,:) openminds.enum.Modules = 'core'
        %force = false
        optionals.ClassNames (1,:) string = missing
    end

    % Retrieve all class names for the selected openMINDS module
    types = module.listTypes();
    typeClassNames = [types.ClassName];

    % Initialize lists to populate
    [sources, targets, edges] = deal(cell(0,1));
    [labels, types] = deal(string.empty);

    numTypes = numel(typeClassNames);

    for i = 1:numTypes
        classFcn = str2func(typeClassNames(i));
        
        try
            tempObj = classFcn();

            propertyNames = properties(tempObj);

            for j = 1:numel(propertyNames)
                iValue = tempObj.(propertyNames{j});

                [~, ~, sourceName] = fileparts( class(tempObj) );

                if isa(iValue, 'openminds.abstract.Schema') && ~isa(iValue, 'openminds.controlledterm.ControlledTerm')
                    [~, ~, targetName] = fileparts( class(iValue) );

                    sources{end+1} = sourceName(2:end); %#ok<AGROW>
                    targets{end+1} = targetName(2:end); %#ok<AGROW>
                    edges{end+1} = propertyNames{j}; %#ok<AGROW>
                
                elseif isa(iValue, 'openminds.internal.abstract.MixedTypeSet')

                    allowedTypes = eval(sprintf("%s.ALLOWED_TYPES", class(iValue)));

                    for k = 1:numel(allowedTypes)
                        [~, ~, targetName] = fileparts( allowedTypes{k} );
                        
                        sources{end+1} = sourceName(2:end); %#ok<AGROW>
                        targets{end+1} = targetName(2:end); %#ok<AGROW>
                        edges{end+1} = propertyNames{j}; %#ok<AGROW>
                    end
                end
            end
        end
    end

    %Todo create a notetable:
    % nodeTable = table(...
    %     string(instanceId), ...
    %     string(instance), ...
    %     string(openminds.internal.utility.getSchemaShortName(class(instance))), ...
    %     'VariableNames', {'Name' 'Label', 'Type'});

    G = digraph(sources,targets);
    if nargout == 2
        edgeLabels = edges;
    end
end
