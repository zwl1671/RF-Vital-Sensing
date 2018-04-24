% This program compares processed NCS and 

% function ncsHxCompare()
%% ------------------------------------------------------------------------
% Provide input to function.
dataPath = ['D:\Research\SummerFall17Spring18\CnC\NCS\Respiratory\',...
    'Hexoskin\Data\3'];
hxFolder = '\user_13412b';
% hxDataNum: 1 = resp_abd, 2 = resp_thrx, 3 = ecg, 4 = tidal_vol_raw,
% 5 = tidal_vol_adj, 6 = min_vent_raw, 7 = min_vent_adj
hxDataNumRespAbd = 1; % Reading abdomen respiration
hxDataNumRespTh = 2; % Reading thorax respiration
hxDataNumTV = 4; % Tidal Volume (TV)
hxDataNumBR = 6; % Breath Rate (BR)
ncsDataNum = 11; % data at different time instants
% Manual time offset is by observation. 
% 20.5 for '2', -1 for '3a: 1-13', 6 for '3b: 14:20'
manualTimeOffset = -1; % sec: This is by observation 
ncsTstart = 0; % Time is relative to NCS in seconds, keep 140 for stable
dataDuration = 0; % Leave last 30 sec abd data: 10*60-32-ncsTstart

%% ------------------------------------------------------------------------
% Synchronization
% First synchronize Hx and NCS raw data: just for observation.
[~,~,~,hxRespTh,tHxResp,hxRespSampRate] = ...
    ncsHxRawSync(dataPath,hxFolder,hxDataNumRespTh,ncsDataNum,...
    manualTimeOffset,dataDuration,ncsTstart);
[~,~,~,hxRespAbd,~,~] = ...
    ncsHxRawSync(dataPath,hxFolder,hxDataNumRespAbd,ncsDataNum,...
    manualTimeOffset,dataDuration,ncsTstart);

% Synchronize NCS and Hx tidal volume (TV) estimation data. 
[ncsSync,tNcs,ncsSampRate,hxTV,tHxTV,hxSampRateTV] = ...
    ncsHxRawSync(dataPath,hxFolder,hxDataNumTV,ncsDataNum,...
    manualTimeOffset,dataDuration,ncsTstart);

% Synchronizing NCS and Hx breathing rate (BR) estimation data.
% Expecting ncsSync to remain the same
[~,~,~,hxBR,tHxBR,hxSampRateBR] = ...
    ncsHxRawSync(dataPath,hxFolder,hxDataNumBR,ncsDataNum,...
    manualTimeOffset,dataDuration,ncsTstart);

%% ------------------------------------------------------------------------
% Process the NCS data to get respiration waveform - both amplitude 
% and phase, after filtering out heartbeat.
% *********************************************************************** %
% Specify correct amplitude and phase sign, see if you can implement algo
% to detect this as well. 
% *********************************************************************** %
fprintf('Change amplitude and phase sign if needed ...\n');
ncsFlipData = [1,1]; % -1 to flip
[ncsResp,~,~,~] = postProcess(0,1,1.4,ncsSync,ncsSampRate,ncsFlipData);

%% ------------------------------------------------------------------------
% Downsample NCS to hx respiration sample rate = 128 Hz
ncsDownSampRate = hxRespSampRate;
ncsRespDS = resample(ncsResp,ncsDownSampRate,ncsSampRate);
% DO NOT use resample for time, as it uses some filter, that creates
% ripple.
tNcsDS = 0:(1/ncsDownSampRate):((length(ncsRespDS)-1)/ncsDownSampRate);

%% ------------------------------------------------------------------------
% Plotting Hexoskin and NCS breaths with TV
close all;

figure('Units', 'pixels', ...
    'Position', [100 100 1200 700]);

nFig = 2;
ax1(1) = subplot(nFig,1,1);
yyaxis left
plot(ax1(1),tHxResp,hxRespTh./max(hxRespTh),':','color','k','LineWidth',2);
hold on
plot(ax1(1),tHxResp,hxRespAbd./max(hxRespAbd),'-','color',[0.3,0.75,0.93]);
plotCute1([],'a.u.',ax1(1),[],[],0);
ylim([0.9967,1.001])
hold off

yyaxis right
plot(ax1(1),tHxTV,hxTV);
plotCute1('Time (sec)','mL',ax1(1),...
    'Hexoskin Respiration (thorax & abdomen) and Tidal Volume',{'Thorax (a.u.)',...
    'Abdomen (a.u.)','Tidal Volume (mL)'},1);

ax1(2) = subplot(nFig,1,2);
yyaxis left
plot(ax1(2),tNcsDS,ncsRespDS(:,1)); 
plotCute1([],'a.u.',ax1(2),[],[],0);

yyaxis right
plot(ax1(2),tNcsDS,ncsRespDS(:,2)); 
plotCute1('Time (sec)','a.u.',ax1(2),...
    'NCS Respiration (amplitude & phase)',{'NCS Amp (a.u.)','NCS Ph (a.u.)'},1);
 
linkaxes(ax1,'x')

%% ------------------------------------------------------------------------
% Find 'inhalation end' and 'exhalation end' indices in amplitude and phase
% inExAmp: Ending of inhalation - peak
% inExPh: Ending of exhalation - minima
[inExAmp, inExPh] = findInhaleExhale(ncsRespDS,ncsDownSampRate);

%% ------------------------------------------------------------------------
% *********************************************************************** %
% Calibrate and Estimate tidal volume with same sampling frequency as Hx.
% Remember to provide correct calibration time. 
% *********************************************************************** %
% calibTime = [tHxTV(1), tHxTV(end)];
calibTime = [40, 100]; % 10-50

[tvCoeffAmpPhSum,tvCoeffAmp,tvCoeffPh,ncsAmpPhTV,tNcsTV] = ...
    ncsEstTV(ncsRespDS,inExAmp,inExPh,hxTV,ncsDownSampRate,hxSampRateTV,calibTime);

ncsTVAmpPhSum = tvCoeffAmpPhSum(1).*ncsAmpPhTV(:,1) + tvCoeffAmpPhSum(2).*...
        ncsAmpPhTV(:,2);
ncsTVAmp = tvCoeffAmp.*ncsAmpPhTV(:,1);
ncsTVPh = tvCoeffPh.*ncsAmpPhTV(:,2);

figure('Units', 'pixels', ...
    'Position', [100 100 900 500]);
ax2 = gca;
plot(tHxTV,hxTV,'color',[0 0.9 0],'LineWidth',2);
hold on
plot(tNcsTV,ncsTVAmpPhSum,'color',[0.5 0.2 0.7],'LineStyle',':','LineWidth',2);
plot(tNcsTV,ncsTVAmp,'color',[0.5,0.7,0.7],'LineWidth',2);
plot(tNcsTV,ncsTVPh,'--','color',[0.9 0.5 0.2]);
hold off
grid on

xLabel = 'Time (sec)';
yLabel = 'Tidal Volume (mL)';
plotTitle = 'Estimated TV from Hexoskin and calibrated TV from NCS';
% plotLegend = {'Hx TV','Ncs TV: A*amp + B*ph','NCS TV: C*amp'};

plotLegend = {'Hx TV','Ncs TV: A*amp + B*ph','NCS TV: C*amp','NCS TV: D*ph'};
plotCute1(xLabel,yLabel,ax2,plotTitle,plotLegend,1);
axis(ax2,'tight')

%% ------------------------------------------------------------------------
% Plotting Hexoskin and NCS breaths with BR

figure('Units', 'pixels', ...
    'Position', [100 100 1200 700]);

nFig = 2;
ax3(1) = subplot(nFig,1,1);
yyaxis left
plot(ax3(1),tHxResp,hxRespTh./max(hxRespTh),':','color','k');
hold on
plot(ax3(1),tHxResp,hxRespAbd./max(hxRespAbd),'-','color',[0.3,0.75,0.93]);
plotCute1([],'a.u.',ax3(1),[],[],0);
ylim([0.995,1.001])
hold off

yyaxis right
plot(ax3(1),tHxBR,hxBR);
plotCute1('Time (sec)','BPM',ax3(1),...
    'Hexoskin Respiration (thorax & abdomen) and Breath Rate',{'Thorax (a.u.)',...
    'Abdomen (a.u.)','Breath Rate (BPM)'},1);

ax3(2) = subplot(nFig,1,2);
yyaxis left
plot(ax3(2),tNcsDS,ncsRespDS(:,1)); 
plotCute1([],'a.u.',ax3(2),[],[],0);

yyaxis right
plot(ax3(2),tNcsDS,ncsRespDS(:,2)); 
plotCute1('Time (sec)','a.u',ax3(2),...
    'NCS Respiration (amplitude & phase)',{'NCS Amp (a.u.)','NCS Ph (a.u.)'},1);
 
linkaxes(ax3,'x')

%% ------------------------------------------------------------------------
% Calculating breath rate from NCS and comparing against Hexoskin. 

[ncsBR,tNcsBR] = ncsEstBR(ncsRespDS,inExAmp,inExPh,hxBR,ncsDownSampRate,hxSampRateBR);

figure('Units', 'pixels', ...
    'Position', [100 100 900 500]);
ax4 = gca;
plot(tHxBR,hxBR,'LineWidth',2,'color',[0.5,0.2,0.7],'LineWIdth',2,'LineStyle',':');
hold on
plot(tNcsBR,ncsBR(:,1),'color',[0 0.9 0],'LineWidth',2);
plot(tNcsBR,ncsBR(:,2),'--','color',[0.9 0.5 0.2],'LineWidth',2);
hold off
grid on

xLabel = 'Time (sec)';
yLabel = 'Breath Per Minute (BPM)';
plotTitle = 'Estimated BR from Hexoskin NCS';
plotLegend = {'Hx BR','NCS Amp BR','NCS Ph BR'};
plotCute1(xLabel,yLabel,ax4,plotTitle,plotLegend,1);
axis(ax4,'tight')

%% ------------------------------------------------------------------------
% Calculating fractional inspiratory time (Ti/Tt)
% Resutls using amplitude and phase waveform for NCS
[ampTiTt,phTiTt] = ncsEstTiTt(ncsRespDS,inExAmp,inExPh,ncsDownSampRate);

%% ------------------------------------------------------------------------
% Results to report: 
% RMSE (Root mean squared Error):
