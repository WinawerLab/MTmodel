% prototypeOnOffDelayDS  Proof-of-concept: direction selectivity from an ON/OFF
% temporal delay + ON/OFF spatial offset (Chariker/Shapley mechanism).
%
% Fully-numeric 1D simulation (space x, time t in frames). A V1 simple cell pools
% an OFF subregion (polarity -, centered at 0) and an ON subregion (polarity +,
% centered at +d, temporal kernel delayed by delta frames). We drive it with
% gratings drifting in the + and - directions across a range of TF, take the F1
% (fundamental) amplitude, and compute a direction-selectivity index
% DSI = (Pref - Opp)/(Pref + Opp).
%
% Predictions (both must hold for the mechanism to be real):
%   * DSI > 0 across the passband when BOTH the ON delay (delta>0) AND the spatial
%     offset (d>0) are present.
%   * DSI ~ 0 when delta=0 OR d=0 (controls).
%   * parasol (fast kernel) and midget (slow kernel) carry DS in different TF
%     bands -> together they cover a broader TF range (relevant to MT speed).
%
% This is exploratory (not model code). delta is in FRAMES; ~1 frame stands in
% for Chariker's ~10 ms pending a frame-rate calibration. See
% docs/RGC_V1_unification_plan.md.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));
set(0,'DefaultFigureVisible','on');

% ---- fixed geometry / stimulus parameters ----
sigma = 3.0;                 % subregion spatial SD (pixels)
fx    = 0.05;                % spatial frequency (cyc/pixel); wavelength = 20 px
d     = 5.0;                 % ON/OFF spatial offset (px) = quarter wavelength -> k*d = pi/2
delta = 1;                   % ON temporal delay (frames)
x     = (-40:0.25:40);       % space grid
Nwin  = 224;                 % steady-state analysis window (frames)
Ntrans= 48;                  % discarded transient (frames)
T     = Nwin + Ntrans;
t     = 0:(T-1);
mList = 1:2:47;              % TF bins -> ft = m/Nwin
ftList= mList / Nwin;        % cyc/frame

% ---- kernels (biological difference-of-gamma, shPars defaults) ----
K.parasol = localBi(0.6,1.2,0.45,2,24);
K.midget  = localBi(2.0,4.0,0.15,2,24);
types = fieldnames(K);

% ---- spatial subregion profiles (Gaussian) ----
RFoff = exp(-0.5*((x-0)/sigma).^2);   RFoff = RFoff/sum(RFoff);
RFon  = exp(-0.5*((x-d)/sigma).^2);   RFon  = RFon /sum(RFon);
RFon0 = exp(-0.5*((x-0)/sigma).^2);   RFon0 = RFon0/sum(RFon0);  % d=0 control

% ---- sweep ----
% Conditions:
%   full    : ON delayed by delta frames + spatial offset (Mechanism #1)
%   delay0  : no delay (control -> DSI should be 0)
%   offset0 : no spatial offset (control -> DSI should be 0)
%   quad    : ON = quadrature (90 deg phase shift) of the kernel, NO time delay
%             (approximates Mechanism #2: a constant-phase ON/OFF difference)
conds = {'full','delay0','offset0','quad'};
res = struct();
for ti = 1:numel(types)
    ker = K.(types{ti});
    kerQuad = localQuad(ker);                         % 90-deg phase-shifted kernel
    for ci = 1:numel(conds)
        cond = conds{ci};
        rfOn = RFon;
        switch cond
            case 'full',    kerOn = [zeros(1,delta) ker];
            case 'delay0',  kerOn = ker;
            case 'offset0', kerOn = [zeros(1,delta) ker]; rfOn = RFon0;
            case 'quad',    kerOn = kerQuad;
        end
        Rp = zeros(size(ftList)); Rm = zeros(size(ftList));
        for fi = 1:numel(ftList)
            ft = ftList(fi);
            Rp(fi) = localF1(+1, ft, fx, x, t, RFoff, rfOn, ker, kerOn, Nwin, Ntrans);
            Rm(fi) = localF1(-1, ft, fx, x, t, RFoff, rfOn, ker, kerOn, Nwin, Ntrans);
        end
        pref = max(Rp,Rm); opp = min(Rp,Rm);
        dsi  = (pref-opp)./(pref+opp+eps);
        res.(types{ti}).(cond) = struct('Rp',Rp,'Rm',Rm,'pref',pref,'opp',opp,'dsi',dsi);
    end
end

% ---- report ----
for ti=1:numel(types)
    d1 = res.(types{ti}).full.dsi; dq = res.(types{ti}).quad.dsi;
    fprintf(['%-8s: delay DSI mean=%.2f (range %.2f-%.2f) | quad DSI mean=%.2f (range %.2f-%.2f) ' ...
             '| controls: delay0=%.3f offset0=%.3f\n'], ...
        types{ti}, mean(d1), min(d1), max(d1), mean(dq), min(dq), max(dq), ...
        mean(res.(types{ti}).delay0.dsi), mean(res.(types{ti}).offset0.dsi));
end

% ---- figure ----
f1=figure('Name','ON/OFF-delay DS prototype','Color','w','Position',[60 80 1180 760]);
tl=tiledlayout(f1,2,2,'TileSpacing','compact','Padding','compact');
title(tl,sprintf('Direction selectivity from ON/OFF delay (\\delta=%d frame) + spatial offset (d=%.0f px, k d=\\pi/2)',delta,d),'FontWeight','bold');
cP=[0.85 0.33 0.10]; cM=[0.00 0.45 0.74];

nexttile; hold on
plot(ftList,res.parasol.full.pref,'-','Color',cP,'LineWidth',1.8);
plot(ftList,res.parasol.full.opp ,'--','Color',cP,'LineWidth',1.4);
plot(ftList,res.midget.full.pref ,'-','Color',cM,'LineWidth',1.8);
plot(ftList,res.midget.full.opp  ,'--','Color',cM,'LineWidth',1.4);
xlabel('TF (cyc/frame)'); ylabel('F1 amplitude'); title('Response: Pref (solid) vs Opp (dashed)');
legend({'parasol Pref','parasol Opp','midget Pref','midget Opp'},'Location','northeast');

nexttile; hold on
plot(ftList,res.parasol.full.dsi,'-','Color',cP,'LineWidth',1.8);
plot(ftList,res.parasol.quad.dsi,'--','Color',cP,'LineWidth',1.6);
plot(ftList,res.midget.full.dsi ,'-','Color',cM,'LineWidth',1.8);
plot(ftList,res.midget.quad.dsi ,'--','Color',cM,'LineWidth',1.6);
ylim([-0.05 1]); xlabel('TF (cyc/frame)'); ylabel('DSI');
title('delay (solid, frequency-dependent) vs quadrature (dashed, broadband)');
legend({'parasol delay','parasol quad','midget delay','midget quad'},'Location','southeast');

nexttile; hold on
plot(ftList,res.parasol.full.dsi   ,'-','Color',cP,'LineWidth',1.8);
plot(ftList,res.parasol.delay0.dsi ,':','Color',cP,'LineWidth',1.6);
plot(ftList,res.parasol.offset0.dsi,'--','Color',cP,'LineWidth',1.2);
ylim([-0.05 1]); xlabel('TF (cyc/frame)'); ylabel('DSI'); title('Controls (parasol): both ingredients required');
legend({'full','\delta=0 (no delay)','d=0 (no offset)'},'Location','northeast');

nexttile; hold on
% combined coverage: sum parasol+midget Pref/Opp -> broader TF band with DS
sp = res.parasol.full; sm = res.midget.full;
combPref = sp.pref+sm.pref; combOpp = sp.opp+sm.opp;
plot(ftList,combPref,'-k','LineWidth',1.8); plot(ftList,combOpp,'--k','LineWidth',1.4);
yyaxis right; plot(ftList,(combPref-combOpp)./(combPref+combOpp+eps),'-','Color',[0.2 0.6 0.2],'LineWidth',1.6);
ylabel('DSI'); ylim([-0.05 1]); yyaxis left; ylabel('F1 amplitude');
xlabel('TF (cyc/frame)'); title('parasol+midget combined (broader TF coverage)');
legend({'comb Pref','comb Opp','comb DSI'},'Location','northeast');

exportgraphics(f1, fullfile(tempdir,'onoff_delay_ds.png'),'Resolution',150);
fprintf('figure shown; PNG at %s\n', fullfile(tempdir,'onoff_delay_ds.png'));

% ================= local functions =================
function amp = localF1(dirSign, ft, fx, x, t, RFoff, RFon, kerOff, kerOn, Nwin, Ntrans)
    k = 2*pi*fx; w = 2*pi*ft;
    % drifting grating I(x,t) = cos(k x - dirSign*w t); dirSign flips motion.
    I = cos( k*x.' - dirSign*w*t );          % Nx x T
    sOff = -(RFoff * I);                      % OFF subregion (polarity -), 1 x T
    sOn  =  (RFon  * I);                      % ON  subregion (polarity +), 1 x T
    rOff = conv(sOff, kerOff); rOff = rOff(1:numel(t));   % causal temporal filtering
    rOn  = conv(sOn,  kerOn ); rOn  = rOn (1:numel(t));
    v = rOn + rOff;                            % V1 simple-cell linear response
    vss = v(Ntrans+1 : Ntrans+Nwin);          % steady-state window
    tt = 0:(Nwin-1);
    amp = 2/Nwin * abs(sum(vss .* exp(-1i*2*pi*ft*tt)));   % F1 magnitude (ft = m/Nwin bin)
end

function k = localBi(tau1,tau2,w,n,L)
    t = 0:(L-1);
    k = (t./tau1).^n.*exp(-t./tau1) - w.*(t./tau2).^n.*exp(-t./tau2);
    k = k./max(abs(k));
end

function q = localQuad(k)
    % 90-degree phase shift at all frequencies (Hilbert transform of the kernel),
    % via the analytic-signal FFT method (no Signal Processing Toolbox needed).
    % NOTE: the exact Hilbert quad is acausal; here it stands in for a constant-
    % phase ON/OFF difference (Chariker Mechanism #2), which biology approximates
    % with a shaped *causal* kernel.
    N = 2^nextpow2(4*numel(k));
    Kf = fft(k, N);
    h = zeros(1,N); h(1)=1; h(N/2+1)=1; h(2:N/2)=2;
    a = ifft(Kf .* h);
    q = imag(a(1:numel(k)));
    if max(abs(q))>0, q = q./max(abs(q)); end
end
