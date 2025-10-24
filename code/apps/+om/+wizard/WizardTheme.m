classdef WizardTheme < wizard.abstract.Theme & om.internal.palette.MaterialPalette

    properties (Constant)
        FontName = 'helvetica';

        HeaderBgColor = om.internal.OpenMindsTheme.PrimaryColorA;
        HeaderMidColor = om.internal.OpenMindsTheme.PrimaryColorB
        HeaderFgColor = [246,248,252]/255;

        FigureBgColor = [246,248,252]/255;
        FigureFgColor = hex2rgb('127e7a')

        MatlabBlue = [16,119,166]/255;
        ControlPanelsBgColor = [1,1,1];
    end
end
