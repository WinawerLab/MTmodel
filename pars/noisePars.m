function cfg = noisePars(varargin)
% noisePars  Defaults for trial-to-trial noise (Step 1: disabled; Step 2: Site 2).
%
% Edit the DEFAULTS block for benchmark runs. Step 2 hooks rng(noiseSeed + tr)
% into shModelV1Normalization_Tuned when cfg.enabled and cfg.site2.enabled.
%
% Usage:
%   cfg = noisePars();
%   cfg = noisePars('nTrials', 20, 'site2.sigma', 0.04);
%
% See also: motionLetterTrials, docs/NOISE_TRIAL_DESIGN.md.

%% ======================== DEFAULTS (edit here) =============================
cfg = struct( ...
    'enabled',              false, ...   % master switch (Step 2)
    'site2', struct( ...
        'enabled',          false, ...
        'mode',             'fixed', ... % locked Step 0
        'sigma',            0.03 ...    % tune in Step 2
    ), ...
    'spatialCorrelation',   'none', ...   % 'none' | 'gaussian' (Phase B)
    'spatialCorrSigmaPx',   3, ...
    'noiseSeed',            9000, ...     % independent of dot seed
    'nTrials',              50 ...
);
%% ==========================================================================

cfg = localApplyOverrides(cfg, varargin);

if ~isstruct(cfg.site2)
    error('noisePars:badSite2', 'cfg.site2 must be a struct.');
end

end

function cfg = localApplyOverrides(cfg, args)
if isempty(args), return; end
if mod(numel(args), 2) ~= 0
    error('noisePars:badArgs', ...
        'Overrides must be name/value pairs, e.g. noisePars(''nTrials'', 10).');
end
for i = 1:2:numel(args)
    key = args{i};
    val = args{i + 1};
    if contains(key, '.')
        cfg = localSetNested(cfg, strsplit(key, '.'), val);
    elseif isfield(cfg, key)
        cfg.(key) = val;
    else
        error('noisePars:unknownField', ...
            'Unknown override ''%s''.', key);
    end
end
end

function cfg = localSetNested(cfg, parts, val)
switch numel(parts)
    case 1
        if ~isfield(cfg, parts{1})
            error('noisePars:unknownField', 'Unknown field ''%s''.', parts{1});
        end
        cfg.(parts{1}) = val;
    case 2
        if ~isfield(cfg, parts{1})
            error('noisePars:unknownField', 'Unknown field ''%s''.', parts{1});
        end
        sub = cfg.(parts{1});
        if ~isfield(sub, parts{2})
            error('noisePars:unknownField', 'Unknown field ''%s.%s''.', parts{1}, parts{2});
        end
        sub.(parts{2}) = val;
        cfg.(parts{1}) = sub;
    otherwise
        error('noisePars:nesting', 'At most one level of nesting supported.');
end
end
