function parsOut = lesionCropForCall(pars, stageName, outputDims)
% lesionCropForCall  Crop full-field maps to the size a tuning call will use.
%
% Used by validateSHFigs9to14_lesions_stochastic.m: each Fig 9-14 panel builds
% a different stimulus size; this crops the shared FieldFull to match.
%
%   pars = lesionCropForCall(pars, 'mtPattern', [1 1 31]);
%
% See also: lesionCropToStim, shGetDims.

if ~isfield(pars.rgc, 'impairmentEnabled') || pars.rgc.impairmentEnabled ~= 1
    parsOut = pars;
    return;
end

d = shGetDims(pars, stageName, outputDims);
parsOut = lesionCropToStim(pars, d(1), d(2));
end
