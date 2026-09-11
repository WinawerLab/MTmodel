function scores = shMatchedFilterScores(map, filters)
% shMatchedFilterScores  Correlate an MT opponent map with each letter's matched filter.
%
%   scores = shMatchedFilterScores(map, filters) returns, for each letter k,
%   the correlation coefficient across pixels between map and
%   filters(:, :, k). The filters from shMatchedFilterTemplates are
%   zero-mean with unit norm; the map is made zero-mean with unit norm here.
%   Each score is therefore in [-1, 1], and does not depend on the map's
%   overall strength, which changes with speed and coherence. The sign
%   follows shOpponentMap: positive when the letter's dots drift right.
%
%   Inputs:
%     map       [Y X] map from shOpponentMap
%     filters   [Y X nLetters], the .maps field of shMatchedFilterTemplates
%
%   Output:
%     scores    [1 nLetters]. All zeros if the map is flat.
%
%   See also shMatchedFilterTemplates, shOpponentMap, shRunLetterTrials

    arguments
        map (:,:) double
        filters (:,:,:) double
    end

    if ~isequal(size(map), [size(filters, 1) size(filters, 2)])
        error("shMatchedFilterScores:size", ...
            "The map is %s but the filters are %s. Build the filters for the same MT output size.", ...
            mat2str(size(map)), mat2str([size(filters, 1) size(filters, 2)]));
    end

    nLetters = size(filters, 3);
    centred = map(:) - mean(map(:));
    mapNorm = norm(centred);
    if mapNorm <= eps
        scores = zeros(1, nLetters);
    else
        scores = (centred.'*reshape(filters, [], nLetters))/mapNorm;
    end
end
