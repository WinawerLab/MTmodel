% playStimMovieCompare(stimA, stimB, ...)
%
% Play two [Y X T] movies side-by-side with matched grey-scale (default [0 1]).
%
% Optional name/value:
%   'labels'     cellstr {left title, right title}
%   'pauseSec'   seconds between frames [1/60]
%   'clim'       color limits [0 1]
%   'maxFrames'  cap playback length (default: all shared frames)

function playStimMovieCompare(stimA, stimB, varargin)

    p = inputParser;
    p.addParameter('labels', {'A', 'B'});
    p.addParameter('pauseSec', 1 / 60);
    p.addParameter('clim', [0 1]);
    p.addParameter('maxFrames', inf);
    p.parse(varargin{:});
    opts = p.Results;

    if ndims(stimA) ~= 3 || ndims(stimB) ~= 3
        error('playStimMovieCompare: inputs must be [Y X T].');
    end
    nFrames = min([size(stimA, 3), size(stimB, 3), opts.maxFrames]);

    fig = figure('Name', 'playStimMovieCompare', 'Color', [0.5 0.5 0.5], ...
        'Position', [60 60 1100 520]);
    colormap(fig, gray(256));
    tl = tiledlayout(fig, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    ax1 = nexttile(tl, 1);
    h1 = imagesc(ax1, stimA(:, :, 1));
    set(ax1, 'CLim', opts.clim);
    axis(ax1, 'image'); axis(ax1, 'off');
    title(ax1, opts.labels{1});

    ax2 = nexttile(tl, 2);
    h2 = imagesc(ax2, stimB(:, :, 1));
    set(ax2, 'CLim', opts.clim);
    axis(ax2, 'image'); axis(ax2, 'off');
    title(ax2, opts.labels{2});

    for t = 1:nFrames
        if ~isgraphics(h1) || ~isgraphics(h2) || ~isgraphics(fig)
            break;
        end
        try
            h1.CData = stimA(:, :, t);
            h2.CData = stimB(:, :, t);
        catch
            break;
        end
        drawnow limitrate;
        if opts.pauseSec > 0
            pause(opts.pauseSec);
        end
    end

end
