% [mask, info] = shClassFeatureMask(pars, pattern)
%
% Build a logical column mask over the class-based V1 feature matrix
% (shClassV1Basis), selecting the columns contributed by RGC classes whose name
% matches a regexp. Used to restrict shFitClassV1Weights to one pathway --
% e.g. the parasol-only fit for the MT-projecting V1 population (docs/MODEL_AND_LESIONS.md
% 2.3).
%
% Column layout: shClassV1Basis walks pars.rgc.classes in order and, for each
% class, emits sum(readoutOrders + 1) contiguous columns. So a class either owns
% a whole contiguous block of columns or none of it. With the lagged preset that
% is 16 classes x 10 read-out combos = 160 columns, parasol first (classes 1-8).
%
% Required arguments:
% pars      parameters with pars.rgc.classes set
% pattern   regexp matched (case-insensitively) against each class's name,
%           e.g. '^parasol' or '^midget'
%
% Output:
% mask      1 x nCols logical; true for columns belonging to matching classes
% info      struct with fields:
%             nCols       total columns in the basis
%             nSelected   number of selected columns
%             names       names of the matching classes
%
% Example:
%   maskP = shClassFeatureMask(pars, '^parasol');   % 80 of 160 for the lagged preset
%   W = shFitClassV1Weights(pars, stimSet, maskP);

function [mask, info] = shClassFeatureMask(pars, pattern)

    if ~isfield(pars, 'rgc') || ~isfield(pars.rgc, 'classes') || isempty(pars.rgc.classes)
        error('shClassFeatureMask:noClasses', 'pars.rgc.classes must be set.');
    end

    classes = pars.rgc.classes;
    mask = false(1, 0);
    names = {};
    for c = 1:numel(classes)
        nCols = sum(classes(c).readoutOrders + 1);
        hit = ~isempty(regexpi(classes(c).name, pattern, 'once'));
        mask = [mask, repmat(hit, 1, nCols)]; %#ok<AGROW>
        if hit
            names{end + 1} = classes(c).name; %#ok<AGROW>
        end
    end

    if ~any(mask)
        warning('shClassFeatureMask:emptyMask', ...
                'Pattern ''%s'' matched no class in pars.rgc.classes.', pattern);
    end

    info = struct('nCols', numel(mask), 'nSelected', sum(mask), 'names', {names});

end
