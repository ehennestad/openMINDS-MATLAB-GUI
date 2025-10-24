function plotModuleGraph(moduleName)
% plotModuleGraph - Plots a graph of the metadata types for a specified module.
%
% Syntax:
%   plotModuleGraph(moduleName)
%
% Input Arguments:
%   moduleName (1,1) openminds.enum.Modules - The name of the module to plot.

    arguments
        moduleName (1,1) openminds.enum.Modules = "core"
    end
    
    G = om.internal.graph.generateGraph(moduleName);
    om.internal.graphics.InteractiveOpenMINDSPlot(G)
end
