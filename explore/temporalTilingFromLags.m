% temporalTilingFromLags  Can biologically-plausible channels tile SH's TF range?
%
% The §2.4 tension: SH's four temporal channels are successive derivatives
% (mono/bi/tri/quad-phasic) that tile TF up to ~0.21 cyc/frame, but real single
% RGC kernels are only mono/biphasic (Kling 2020) -- orders 0-1. MT needs the full
% TF range for speed tuning. Fork (§14): (i) synthesize the high-TF channels from
% biologically-plausible pieces, or (ii) accept a narrower range.
%
% This tests (i). Key idea: a difference of two LAGGED biphasic kernels
% approximates a temporal derivative (k(t)-k(t-D) ~ D dk/dt), so a bank of
% biphasic channels + small lags should span higher orders -- and each channel
% stays mono/biphasic (plausible); the high-order structure lives in the LINEAR
% COMBINATION (the V1 read-out), not in any single cell. We reconstruct each SH
% derivative kernel from banks of increasing richness and report R2 per order.
%
% If orders 2-3 reconstruct well from a plausible bank -> the high-TF gap is
% synthesizable via lags (option i). If they stay poor -> irreducible (option ii).
%
% Self-locating; PNG to tempdir.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));
outDir = tempdir;

pars = shPars;
TF = pars.v1TemporalFilters;                 % [fsz x 4], SH orders 0..3
fsz = size(TF,1);
L = 20;                                      % common time grid
T = zeros(L,4);                              % zero-padded SH targets
for o = 1:4, T(1:fsz,o) = TF(:,o); end

% --- three banks of biologically-plausible (mono/biphasic) channels ---
% bank A: the 2 current kernels (fast/parasol, slow/midget), NO lags
A = [localBi(0.6,1.2,0.45,L) localBi(2.0,4.0,0.15,L)];
% bank B: same 2 timescales x small lags 0..3 frames
B = localBankLags([0.6 2.0], [1.2 4.0], [0.45 0.15], 0:3, L);
% bank C: richer -- 5 timescales x lags 0..4 (still each mono/biphasic)
tau1 = [0.6 1.0 1.5 2.0 2.6]; tau2 = 2*tau1; w = 0.35*ones(size(tau1));
C = localBankLags(tau1, tau2, w, 0:4, L);

banks = {A,B,C};
names = {'2 kernels, no lags (current)','2 timescales x lags 0-3','5 timescales x lags 0-4'};

fprintf('Reconstructing SH temporal-derivative kernels from biological banks.\n');
fprintf('Each channel is mono/biphasic (<=1 zero crossing); high order must come\n');
fprintf('from the linear combination.\n\n');
R2 = zeros(numel(banks),4);
for b = 1:numel(banks)
    Bk = banks{b};
    fprintf('%-30s (%d channels):  R2 by SH order [0 1 2 3] = ', names{b}, size(Bk,2));
    for o = 1:4
        coef = Bk \ T(:,o);
        resid = T(:,o) - Bk*coef;
        R2(b,o) = 1 - (resid'*resid)/max(T(:,o)'*T(:,o), eps);
        fprintf('%.3f ', R2(b,o));
    end
    fprintf('\n');
end

% --- reconstruct order-2 and order-3 (the hard ones) with the richest bank ---
recon = zeros(L,4);
for o = 1:4, recon(:,o) = banks{3} * (banks{3} \ T(:,o)); end

% --- figure ---
f = figure('Color','w','Position',[60 80 1100 460]);
subplot(1,2,1);
bar(0:3, R2'); ylim([0 1.05]); grid on;
xlabel('SH temporal order'); ylabel('reconstruction R^2 from biological bank');
legend(names,'Location','southwest');
title({'Can biphasic + lagged channels tile SH''s TF range?','(order 2-3 = the high-TF gap)'});
subplot(1,2,2); hold on;
plot(0:L-1, T(:,3),'-o','LineWidth',1.6,'Color',[0.85 0.33 0.10]);
plot(0:L-1, recon(:,3),'--','LineWidth',1.6,'Color',[0.85 0.33 0.10]);
plot(0:L-1, T(:,4),'-s','LineWidth',1.6,'Color',[0 0.45 0.74]);
plot(0:L-1, recon(:,4),'--','LineWidth',1.6,'Color',[0 0.45 0.74]);
yline(0,'k:'); xlim([0 fsz+2]); xlabel('lag (frames)'); ylabel('amp');
legend({'SH order 2 (true)','order 2 (bank recon)','SH order 3 (true)','order 3 (bank recon)'}, ...
       'Location','best');
title('High-TF kernels: bank reconstruction (richest bank)');
sgtitle('Synthesizing SH high-TF channels from mono/biphasic RGC kernels + lags');
exportgraphics(f, fullfile(outDir,'temporalTiling_lags.png'), 'Resolution',150);
fprintf('\nWrote %s\n', fullfile(outDir,'temporalTiling_lags.png'));

% =====================================================================
function k = localBi(tau1,tau2,w,L)
    t = 0:(L-1);
    k = (t./tau1).^2 .* exp(-t./tau1) - w.*(t./tau2).^2 .* exp(-t./tau2);
    k = k(:) ./ max(abs(k));
end
function Bk = localBankLags(tau1, tau2, w, lags, L)
    Bk = [];
    for i = 1:numel(tau1)
        base = localBi(tau1(i), tau2(i), w(i), L);
        for d = lags
            col = [zeros(d,1); base]; col = col(1:L);
            Bk = [Bk col]; %#ok<AGROW>
        end
    end
end
