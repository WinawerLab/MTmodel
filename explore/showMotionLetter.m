% showMotionLetter  Preview a motion-defined letter stimulus (mkMotionLetter).
%
% Self-locating script. Generates the movie, shows a static letter-mask
% diagnostic, a single frame snapshot, and plays the full sequence with
% playStimMovie (fixed [0 1] grey scale — not flipBook, which auto-scales
% each frame and makes the 0.5 background look black).
%
% Edit PRESET below: 'quick' (fast, smaller field) or 'experiment' (1280×960, 4 s).
%
% Usage:
%   run explore/showMotionLetter.m

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

PRESET = 'quick';   % 'quick' | 'experiment'

switch lower(PRESET)
    case 'experiment'
        % Matches Experiment.m window size and Parameters.m defaults (speed block)
        stimSz = [960 1280 240];   % 4 s @ 60 Hz, Y×X
        letter = 'C';
        args = { ...
            'dotSpeedDegS', 0.45, ...
            'letterSizeArcmin', 168, ...
            'dotContrast', 1.0, ...
            'drawBackgroundDots', true, ...
            'frameRate', 60, ...
            'screenWidthCm', 39, ...
            'viewDistCm', 175, ...
            'seed', 1 ...
        };
    otherwise
        % Smaller / fewer frames for a fast sanity check
        stimSz = [480 480 90];     % 1.5 s @ 60 Hz
        letter = 'H';
        args = { ...
            'dotSpeedDegS', 0.45, ...
            'letterSizeArcmin', 168, ...
            'dotContrast', 1.0, ...
            'drawBackgroundDots', true, ...
            'frameRate', 60, ...
            'screenWidthCm', 39, ...
            'viewDistCm', 175, ...
            'seed', 1 ...
        };
end

fprintf('Generating motion letter ''%s'' (%s preset)...\n', letter, PRESET);
tic;
[stim, info] = mkMotionLetter(stimSz, letter, args{:});
fprintf('Done in %.1f s.  size = [%d %d %d], letterContrast = %.3f\n', ...
    toc, size(stim, 1), size(stim, 2), size(stim, 3), info.letterContrast);
fprintf('  dotSpeed = %.3f deg/s (%.4f px/frame), letterSize = %d px, font = %s\n', ...
    info.dotSpeedDegS, info.dotSpeedPxPerFrame, info.letterSizePx, info.fontName);

% --- Figure 1: letter mask used for compositing ---
figure('Name', 'mkMotionLetter: letter mask', 'Color', 'w', 'Position', [80 520 520 420]);
subplot(1, 2, 1);
imagesc(info.binaryMask); axis image off; colormap(gca, gray);
title(sprintf('Letter mask (''%s'')', letter));
subplot(1, 2, 2);
imagesc(info.binaryMask); axis image off; colormap(gca, gray);
hold on;
contour(info.binaryMask, [0.5 0.5], 'r', 'LineWidth', 1);
title('Mask contour');
hold off;

% --- Figure 2: middle frame ---
midT = round(size(stim, 3) / 2);
figure('Name', 'mkMotionLetter: single frame', 'Color', 'w', 'Position', [620 520 480 420]);
imagesc(stim(:, :, midT), [0 1]); axis image off; colormap(gca, gray);
title(sprintf('Frame %d / %d (mid trial)', midT, size(stim, 3)));

% --- Figure 3: play movie (fixed grey scale, square pixels) ---
figure('Name', 'mkMotionLetter: playback', 'Color', [0.5 0.5 0.5]);
fprintf('Playing stimulus with playStimMovie (caxis [0 1])...\n');
playStimMovie(stim, 1 / 60, [0 1]);

% --- Optional: contrast block (no background dots) ---
fprintf('\nContrast-block variant (no background dots):\n');
[stimC, infoC] = mkMotionLetter(stimSz, letter, args{:}, 'drawBackgroundDots', false, 'dotContrast', 0.5);
fprintf('  dotContrast = %.2f, letterContrast = %.3f\n', infoC.dotContrast, infoC.letterContrast);
figure('Name', 'mkMotionLetter: contrast block (no bg dots)', 'Color', 'w');
imagesc(stimC(:, :, midT), [0 1]); axis image off; colormap(gca, gray);
title(sprintf('Contrast condition, frame %d', midT));

fprintf('\nTo try other letters/conditions, edit PRESET or call mkMotionLetter directly.\n');
