% compareTemporalKernels  SH temporal-derivative basis vs biological kernels.
%
% Plots the 4 SH temporal kernels (v1TemporalFilters, orders 0-3) and the
% biological difference-of-gamma kernels (fast/parasol, slow/midget) currently
% in the code, in time and as amplitude spectra (cyc/frame). Prints zero-
% crossings and peak temporal frequency.
%
% Point: SH kernels tile TF up to ~0.215 cyc/frame (orders 0-3); the biological
% kernels peak only at ~0.10 (fast) and ~0.02 (slow), covering the lower half.
% The high-TF (order 2-3) channels have no single-RGC counterpart -- relevant to
% MT speed tuning. See docs/RGC_V1_unification_plan.md §2.4. Compare with Kling
% (2020) Fig. 4A (all human classes mono/biphasic).
%
% Self-locating.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));
set(0, 'DefaultFigureVisible', 'on');

pars = shPars;
TF = pars.v1TemporalFilters; fsz = size(TF,1);

% biological difference-of-gamma kernels (shPars defaults); n=2 power
kFast = localBi(0.6,1.2,0.45,2,24);   % fast / parasol-like
kSlow = localBi(2.0,4.0,0.15,2,24);   % slow / midget-like

NFFT=512; f=(0:NFFT/2)/NFFT;
specHalf = @(k) localSpecHalf(k, NFFT);
zc = @(k) sum(abs(diff(sign(k(abs(k)>1e-6*max(abs(k)))))) > 0);
peakF = @(k) f(find(specHalf(k)==max(specHalf(k)),1));

fprintf('--- SH temporal-derivative kernels ---\n');
for o=0:3
    fprintf('order %d: zero-crossings=%d  peakTF=%.3f cyc/frame\n', o, zc(TF(:,o+1)), peakF(TF(:,o+1)));
end
fprintf('--- biological (difference-of-gamma) ---\n');
fprintf('fast/parasol: zero-crossings=%d  peakTF=%.3f cyc/frame\n', zc(kFast), peakF(kFast));
fprintf('slow/midget : zero-crossings=%d  peakTF=%.3f cyc/frame\n', zc(kSlow), peakF(kSlow));

f1=figure('Name','SH vs biological temporal kernels','Color','w','Position',[60 120 1180 720]);
tl=tiledlayout(f1,2,2,'TileSpacing','compact','Padding','compact');
title(tl,'SH temporal-derivative basis (orders 0-3) vs biological midget/parasol kernels','FontWeight','bold');
cols=lines(4);

nexttile; hold on
for o=0:3, plot(0:fsz-1, TF(:,o+1)/max(abs(TF(:,o+1))),'-o','Color',cols(o+1,:),'LineWidth',1.6); end
yline(0,'k:'); title('SH kernels (time, peak-normalized)'); xlabel('lag (frames)'); ylabel('amp')
legend(arrayfun(@(o)sprintf('order %d',o),0:3,'uni',0),'Location','best')

nexttile; hold on
for o=0:3
    plot(f, specHalf(TF(:,o+1))/max(specHalf(TF(:,o+1))),'-','Color',cols(o+1,:),'LineWidth',1.6);
    xline(peakF(TF(:,o+1)),':','Color',cols(o+1,:));
end
title('SH amplitude spectra (peaks march up with order)'); xlabel('temporal freq (cyc/frame)'); ylabel('|A| norm'); xlim([0 0.5])

nexttile; hold on
plot(0:23, kFast/max(abs(kFast)),'-o','Color',[0.85 0.33 0.10],'LineWidth',1.6);
plot(0:23, kSlow/max(abs(kSlow)),'-o','Color',[0.00 0.45 0.74],'LineWidth',1.6);
yline(0,'k:'); title('biological kernels (time, peak-normalized)'); xlabel('lag (frames)'); ylabel('amp')
legend({'fast / parasol-like','slow / midget-like'},'Location','best')

nexttile; hold on
plot(f, specHalf(kFast)/max(specHalf(kFast)),'-','Color',[0.85 0.33 0.10],'LineWidth',1.6);
plot(f, specHalf(kSlow)/max(specHalf(kSlow)),'-','Color',[0.00 0.45 0.74],'LineWidth',1.6);
for o=0:3, xline(peakF(TF(:,o+1)),':','Color',[.6 .6 .6]); end
title('biological spectra (grey ticks = SH order peaks)'); xlabel('temporal freq (cyc/frame)'); ylabel('|A| norm'); xlim([0 0.5])

exportgraphics(f1, fullfile(tempdir,'temporal_compare.png'), 'Resolution',150);
fprintf('figure shown; PNG written to %s\n', fullfile(tempdir,'temporal_compare.png'));

function k=localBi(tau1,tau2,w,n,L)
    t=0:(L-1);
    k=(t./tau1).^n.*exp(-t./tau1) - w.*(t./tau2).^n.*exp(-t./tau2);
    k=k./max(abs(k));
end
function y=localSpecHalf(k, NFFT)
    a=abs(fft(k(:)'/max(abs(k)), NFFT));
    y=a(1:NFFT/2+1);
end
