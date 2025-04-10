function [G, edgeLabels] = generateGraph(modelName)
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
    % Modify schemas to include incoming links/edges.

    arguments
        modelName = 'core'
        %force = false
    end

    [s, t, e] = deal(cell(0,1));

    types = enumeration( 'openminds.enum.Types' );
    classNames = [types.ClassName];
    keep = startsWith( classNames, sprintf('openminds.%s', modelName) );
    classNames = classNames(keep);

    numTypes = numel(classNames);

    for i = 1:numTypes
        classFcn = str2func(classNames(i));
        
        try
            tempObj = classFcn();

            propertyNames = properties(tempObj);

            for j = 1:numel(propertyNames)
                iValue = tempObj.(propertyNames{j});

                [~, ~, sourceName] = fileparts( class(tempObj) );

                if isa(iValue, 'openminds.abstract.Schema') && ~isa(iValue, 'openminds.controlledterm.ControlledTerm')
                    [~, ~, targetName] = fileparts( class(iValue) );

                    s{end+1} = sourceName(2:end); %#ok<AGROW>
                    t{end+1} = targetName(2:end); %#ok<AGROW>
                    e{end+1} = propertyNames{j}; %#ok<AGROW>
                elseif isa(iValue, 'openminds.internal.abstract.LinkedCategory')

                    allowedTypes = eval(sprintf("%s.ALLOWED_TYPES", class(iValue)));

                    for k = 1:numel(allowedTypes)
                        [~, ~, targetName] = fileparts( allowedTypes{k} );
                        
                        s{end+1} = sourceName(2:end); %#ok<AGROW>
                        t{end+1} = targetName(2:end); %#ok<AGROW>
                        e{end+1} = propertyNames{j}; %#ok<AGROW>
                    end
                end
            end
        end
    end

    G = digraph(s,t);
    if nargout == 2
        edgeLabels = e;
    end
end
