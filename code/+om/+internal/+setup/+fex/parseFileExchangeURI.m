function [packageUuid, version] = parseFileExchangeURI(uri)
% parseFileExchangeURI - Get UUID and version for package
%
%   NB: This function relies on an undocumented api, and might break in the
%   future.

    version = "latest"; % Initialize default value

    FEX_API_URL = "https://addons.mathworks.com/registry/v1/";
    
    splitUri = strsplit(uri, '/');

    packageNumber = regexp(splitUri{2}, '\d*(?=-)', 'match', 'once');
    try
        packageInfo = webread(FEX_API_URL + num2str(packageNumber));
        packageUuid = packageInfo.uuid;
    catch ME
        switch ME.identifier
            case 'MATLAB:webservices:HTTP404StatusCodeError'
                error('FEX package with identifier "%s" was not found', splitUri{2})
            otherwise
                rethrow(ME)
        end
    end

    if numel(splitUri) == 3
        version = string( splitUri{3} );
        assert( any(strcmp(packageInfo.versions, version) ), ...
            'Specified version "%s" is not supported for FEX package "%s"', ...
            version, splitUri{2});
    end
end
