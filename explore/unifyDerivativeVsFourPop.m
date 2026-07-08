% unifyDerivativeVsFourPop  Show that 'derivative' and 'fourPop' are the SAME
% machinery with different RGC-class parameters.
%
% Runs the general fourPop-style projection (4 RGC classes x 10 spatial-
% derivative read-outs = 40 features) + ridge fit, swapping ONLY the RGC
% classes. Evaluates correlation vs the legacy (RGC-disabled) model on a
% held-out stimulus set.
%
% Expected: derivative classes -> ~0.9999 (1.0 modulo ridge), fourPop -> ~0.69,
% and the derivative 40-feature projection contains the exact 10-column
% structured basis (cross-check err = 0). See docs/RGC_V1_unification_plan.md §2.2.
%
% Self-locating.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));
rng(0);

pars = shPars;
scale = pars.scaleFactors.v1Linear;
parsLeg = pars; parsLeg.rgc.enabled = 0;
parsDer = pars; parsDer.rgc.enabled = 1; parsDer.rgc.mode = 'derivative';
parsFP  = pars; parsFP.rgc.enabled  = 1; parsFP.rgc.mode  = 'fourPop'; parsFP.rgc.v1Weights = [];

dims = shGetDims(pars, 'mtPattern', [1 1 18]);
mkGr = @(th,sp,c) mkSin(dims, th, subsref(v12sin([th sp]),struct('type','()','subs',{{2}})), ...
                                subsref(v12sin([th sp]),struct('type','()','subs',{{3}})), c);
trainSet = { mkDots(dims,0,1.0,0.12,1), mkDots(dims,pi/2,0.7,0.12,0.7), ...
             mkGr(0,1.0,1), mkGr(pi/3,1.6,1), mkGr(pi,0.8,1), mkGr(-pi/4,1.2,1) };
testSet  = { mkDots(dims,pi/4,0.9,0.12,1), mkGr(pi/6,1.3,1), mkGr(2*pi/3,0.9,1), ...
             mkDots(dims,pi,0.6,0.12,0.8) };

SF = pars.v1SpatialFilters; fsz = size(SF,1); order = 3;
buildS = @(chStruct) localBuildS(chStruct, @(mv) localProj(mv,SF,fsz,order));

% cross-check: derivative 40-feature S contains the exact 10-col structured basis
s0 = trainSet{1};
Sder40 = buildS(shModelRgcDerivative(s0, parsDer).channels);
[~,~,Sstruct10] = shModelV1LinearFromRgcDerivative(s0, parsDer);
[tC,~,~] = localComboOrders(order);
sel = arrayfun(@(n) tC(n)*10 + n, 1:10);
fprintf('cross-check (derivative 40-feat contains exact 10-col basis): max err = %.3e\n', ...
        max(abs(Sder40(:,sel) - Sstruct10), [], 'all'));

resDer = localFitEval(trainSet, testSet, parsLeg, scale, @(s) buildS(shModelRgcDerivative(s,parsDer).channels));
resFP  = localFitEval(trainSet, testSet, parsLeg, scale, @(s) buildS(shModelRgc(s,parsFP).channels));

fprintf('\n=========== RESULT (held-out test set) ===========\n');
fprintf('DERIVATIVE classes -> corr = %.6f  NRMSE = %.6f  (nFeat=%d)\n', resDer.corr, resDer.nrmse, resDer.nFeat);
fprintf('fourPop    classes -> corr = %.6f  NRMSE = %.6f  (nFeat=%d)\n', resFP.corr,  resFP.nrmse,  resFP.nFeat);
fprintf('==================================================\n');

% ---- local functions ----
function [tC,xC,yC] = localComboOrders(order)
    tC=[];xC=[];yC=[];
    for torder=0:order
        for xorder=0:(order-torder)
            tC(end+1)=torder; xC(end+1)=xorder; yC(end+1)=order-torder-xorder; %#ok<AGROW>
        end
    end
end
function S = localProj(movie, SF, fsz, order)
    movie = movie(:,:,fsz:end);
    n=1; S=[];
    for torder=0:order
        for xorder=0:(order-torder)
            yorder=order-torder-xorder;
            xfilt=reshape(SF(:,xorder+1),[1 fsz 1]);
            yfilt=reshape(flipud(SF(:,yorder+1)),[fsz 1 1]);
            tmp=shValidCorrDn3(shValidCorrDn3(movie,yfilt),xfilt); tmp=tmp(:);
            if isempty(S), S=zeros(numel(tmp),10); end
            S(:,n)=tmp; n=n+1; %#ok<AGROW>
        end
    end
end
function S = localBuildS(chStruct, projFun)
    names=fieldnames(chStruct); S=[];
    for c=1:numel(names)
        Sc=projFun(chStruct.(names{c}));
        if isempty(S), S=zeros(size(Sc,1),numel(names)*10); end
        S(:,(c-1)*10+1:c*10)=Sc; %#ok<AGROW>
    end
end
function res = localFitEval(trainSet, testSet, parsLeg, scale, Sfun)
    Str=[]; Ttr=[];
    for i=1:numel(trainSet)
        s=trainSet{i}; tgt=shModelV1Linear(s,parsLeg)/scale;
        Str=[Str; Sfun(s)]; Ttr=[Ttr; tgt]; %#ok<AGROW>
    end
    nW=size(Str,2); nN=size(Ttr,2);
    A=Str'*Str + (1e-4*trace(Str'*Str)/nW)*eye(nW);
    W=zeros(nN,nW); for n=1:nN, W(n,:)=(A\(Str'*Ttr(:,n)))'; end
    Pte=[]; Tte=[];
    for i=1:numel(testSet)
        s=testSet{i}; tgt=shModelV1Linear(s,parsLeg)/scale;
        Pte=[Pte; Sfun(s)*W']; Tte=[Tte; tgt]; %#ok<AGROW>
    end
    res=struct('corr',corr(Pte(:),Tte(:)), ...
               'nrmse',sqrt(mean((Pte(:)-Tte(:)).^2))/(max(Tte(:))-min(Tte(:))), ...
               'nFeat',nW);
end
