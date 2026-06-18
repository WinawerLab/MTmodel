function [wts, kori, ksf, ktf] = shModelV1Normalization_TunedWts(newDirs, dirs)
% Returns uniform normalization weights (tuned weighting not yet implemented).
wts = ones(size(newDirs, 1), size(dirs, 1));
