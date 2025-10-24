classdef SchemaTableColumnFormatter < nansen.metadata.abstract.TableVariable & nansen.metadata.abstract.TableColumnFormatter

    properties (Constant)
        IS_EDITABLE = false
        DEFAULT_VALUE = ''
    end

    methods

        function obj = SchemaTableColumnFormatter(S)
            if ~nargin; S = ''; end
            obj@nansen.metadata.abstract.TableVariable(S);
        end

        function str = getCellDisplayString(obj)

            numValues = numel(obj);

            if isenum(obj(1).Value)
                str = cellfun(@(c) char(c), {obj(:).Value}, 'UniformOutput', false);
            else
                str = cell(numValues, 1);
                for i = 1:numValues
                    if isempty(obj(i).Value)
                        str{i} = 'Missing';
                    else
                        subStr = repmat("", 1, numel(obj(i).Value));
                        for j = 1:numel(obj(i).Value)
                            subStr(j) = obj(i).Value(j).DisplayString;
                        end
                        str{i} = strjoin(subStr, ', ');
                    end
                end

                % str = class(obj(1).Value);
                % str = repmat({str}, numel(obj), 1);
            end
        end

        function str = getCellTooltipString(obj)

            if isa(obj(1).Value, 'openminds.controlledterms.ControlledTerm')
            end
        end
    end
end
