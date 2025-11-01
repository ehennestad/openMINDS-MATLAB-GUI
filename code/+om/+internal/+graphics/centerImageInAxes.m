function centerImageInAxes(hAxes, hImage, opts)
%CENTERIMAGEINAXES Adjust axes limits to center an image without clipping.
%   [XLIM, YLIM] = om.internal.graphics.CENTERIMAGEINAXES(hAxes, hImage) adjusts 
%   XLim and YLim of hAxes so that the image (hImage) is centered and fully
%   visible, respecting aspect ratio.
%
%   [XLIM, YLIM] are also returned as 1x2 vectors.
%
%   Optional arguments (name-value):
%     Padding - Fractional padding around fitted span (e.g., 0.02 = 2% padding)
%
%   Example:
%     I = imread('peppers.png');
%     ax = axes;
%     hImg = image(ax, I);
%     axis(ax, 'ij');
%     om.internal.graphics.centerImageInAxes(ax, hImg, Padding=0.05);
    
    arguments
        hAxes (1,1) matlab.graphics.axis.Axes
        hImage (1,1) matlab.graphics.primitive.Image
        opts.Padding (1,1) double {mustBeNonnegative} = 0
    end
    
    % Extract image extents in data units
    xData = hImage.XData;
    yData = hImage.YData;
    
    if numel(xData) == 2
        xLimImg = xData;
    else
        xLimImg = [min(xData), max(xData)];
    end
    
    if numel(yData) == 2
        yLimImg = yData;
    else
        yLimImg = [min(yData), max(yData)];
    end
    
    % Image center and aspect ratio
    centerX = mean(xLimImg);
    centerY = mean(yLimImg);
    imageWidth = diff(xLimImg);
    imageHeight = diff(yLimImg);
    imageAspectRatio = imageWidth / imageHeight;
    
    % Compute plot-box aspect ratio (width/height)
    axesPosition = hAxes.Position;
    axesTightInset  = hAxes.TightInset;
    axesWidth = max(axesPosition(3) - (axesTightInset(1)+axesTightInset(3)), eps);
    axesHeight = max(axesPosition(4) - (axesTightInset(2)+axesTightInset(4)), eps);
    axesAspectRatio = axesWidth / axesHeight;
    
    % Determine which dimension to expand
    if axesAspectRatio > imageAspectRatio
        % Axes is relatively wider → expand X span
        wFit = imageWidth * axesAspectRatio;
        padX = opts.Padding * wFit;
        padY = opts.Padding * imageHeight;
        xLimOut = [centerX - wFit/2 - padX, centerX + wFit/2 + padX];
        yLimOut = [yLimImg(1) - padY, yLimImg(2) + padY];
    else
        % Axes is relatively taller → expand Y span
        hFit = imageHeight / axesAspectRatio;
        padX = opts.Padding * imageWidth;
        padY = opts.Padding * hFit;
        xLimOut = [xLimImg(1) - padX, xLimImg(2) + padX];
        yLimOut = [centerY - hFit/2 - padY, centerY + hFit/2 + padY];
    end
    
    % Apply limits
    hAxes.XLim = xLimOut;
    hAxes.YLim = yLimOut;
    
    % Preserve aspect ratio (pixels look correct)
    hAxes.DataAspectRatioMode = 'manual';
    hAxes.DataAspectRatio = [1 1 1];

    if ~nargout
        clear xLimOut yLimOut
    end
end
