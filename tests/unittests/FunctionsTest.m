classdef FunctionsTest < matlab.unittest.TestCase

    methods(TestClassSetup)
        % Shared setup for the entire test class
    end
    
    methods(TestMethodSetup)
        % Setup for each test
    end
    
    methods(Test)

        function testpathstr2packagename(testCase)
            projectDirectory = omuitools.projectdir;
            pathStr = fullfile(projectDirectory, 'code', '+om', '+internal', '+strutil');
            packageName = om.internal.strutil.pathstr2packagename(pathStr);
            testCase.verifyEqual(string(packageName),"om.internal.strutil")
        end
    end
end