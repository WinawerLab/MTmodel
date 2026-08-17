% playStimMovie(stim, pauseSec, clim)
%
% Play a [Y X T] stimulus movie with correct grey-level display.
% Unlike flipBook(..., 'default'), this keeps caxis fixed (default [0 1])
% so a 0.5 grey background appears mid-grey, not black.
%
% Required:
%   stim       [Y X T] movie, typically in [0  1]
%
% Optional:
%   pauseSec   seconds between frames [1/60]
%   clim       color limits [0 1]

function playStimMovie(stim, pauseSec, clim)

    if nargin < 2 || isempty(pauseSec)
        pauseSec = 1 / 60;
    end
    if nargin < 3 || isempty(clim)
        clim = [0 1];
    end

    if ndims(stim) ~= 3
        error('playStimMovie: stim must be [Y X T].');
    end

    fig = gcf;
    if ~ishandle(fig)
        figure('Name', 'playStimMovie', 'Color', [0.5 0.5 0.5]);
    else
        set(fig, 'Color', [0.5 0.5 0.5]);
    end

    ax = gca;
    if isempty(ax) || ~ishandle(ax)
        ax = axes('Parent', fig);
    end

    h = imagesc(stim(:, :, 1), clim);
    axis(ax, 'image');
    axis(ax, 'off');
    colormap(ax, gray(256));

    for t = 1:size(stim, 3)
        set(h, 'CData', stim(:, :, t));
        drawnow;
        if pauseSec > 0
            pause(pauseSec);
        end
    end

end
