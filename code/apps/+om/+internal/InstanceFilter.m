classdef InstanceFilter < handle
% InstanceFilter - Class for defining properties and methods for filtering instances

    % Todo: Remove default values and provide examples using strcmp,
    % regexp, isequal etc
    properties
        PropertyName (1,1) string = 'species.name';
        FilterFunction (1,1) string = 'strcmp';
        FilterCondition = 'rattusNorvegicus';
    end
    
    methods
        function instances = apply(obj, instances)
            values = cell(1,numel(instances));
            for i = 1:numel(instances)
                values{i} = eval( sprintf('instances(i).%s', obj.PropertyName) );
            end
            try
                values = [values{:}];
            catch
                % values is a cell array
            end
            keep = feval(obj.FilterFunction, values, obj.FilterCondition);
            instances = instances(keep);
        end
    end
end
