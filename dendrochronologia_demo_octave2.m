% This is a demo script for the Octave version of the Vaganov-Shashkin model (VSM)
% This script produces the analyses for Mohonk in Anchukaitis et al. 2019 (submitted)
clear; close all; clc; % clean up the workspace

if false # for REPL
  cd('C:\vsm');
  dir();
end

% get the Mohonk hemlock chronology, NY004r, Cook and Jacoby 1977
% originally from: https://www.ncdc.noaa.gov/paleo-search/study/3000
mohonk

%% read in the climate data
% the file will have to be in your current directory or your path
% in the workspace, make sure you have P, T, syear, eyear, and phi
load('305426_mohonk.mat');

% smooth the input temperature to follow Vaganov et al. 2011
TV = vsm_filter(T,'V'); 
TA = vsm_filter(T,'A'); 
TL = vsm_filter(T,'L'); 

len=length(T(:,1));
plot(1:len,T0(:,1),1:len,TV(:,1),1:len,TA(:,1),1:len,TL(:,1));

T=TA;

%% read in the parameter file
#todo read VS-Fortran5 format 
a06_parameters % parameter file from Anchukaitis et al. 2006
parameters.rated = 0.0115;  % change drainage rate for the 'Humpty Dumpty' rocky slope at Mohonk from Vaganov et al. 2011

% use a Latin Hypercube design to sample from the parameter space for Tf(1)
% and Tf(2) - you may wish to use a smaller design matrix (ensembleSize) to make this demo run faster

f = @vsm;
DIM = 2;
BOX =  [[0; 10], [5; 20]]; # [0 10; 5 20]
NI = 1000;

ensembleSize = NI; 
pkg load stk;
# https://octave.sourceforge.io/stk/function/stk_sampling_randomlhs.html
# https://rdrr.io/cran/lhs/api/
X = stk_sampling_randomlhs (NI, DIM, BOX);

% overlapping period of meteorological data and tree-ring chronology
[~,idx1,idx2] = intersect(crn(:,1),syear:eyear);

%% create an ensemble of reconstructions using the design matrix
% beware that this look can take quite a long time (>150 seconds)! 
# depending on the size of the design matrix X
if 1 % use this to skip the loop by setting to 0 instead of 1
outputt2 = NaN(length(syear:eyear), NI);
tic 
for i = 1:NI
     % https://stackoverflow.com/questions/55391844/octave-converting-dataframe-to-cell-array
     parameters.Tf(1) = struct(X).data(i,1);
     parameters.Tf(2) = struct(X).data(i,2);
     output(i) = vsm(T,P,phi,syear,eyear,parameters);
     outputt2(:,i) = output(i).trw';
     disp(i);
     % 
end % end the looping over parameters in the design matrix
end % ends the if/end skip
toc
#
NI=145;
out2=outputt2;
o2=outputt2(:,[1:145]);
outputt2=o2;
% calculate the correlation between the actual and simulated ensemble
[R,P] = corrcoef([crn(idx1,2) outputt2(idx2,:)]);
R0 = R(2:end,1);

% if you've previously run the code through the above loop, you may wish to save the output and 
% skip the loop in order to speed up this demo
save mohonk_temperature_ensemble_lhs2.mat
# pkg load stk;
% load mohonk_temperature_ensemble_lhs2.mat
% calculate mean growth rates over years for the ensemble members
pkg load statistics
for j = 1:NI
    meanGrowthRate(:,j) = nanmean(output(j).Gr,2);
    meanGrowthRateT(:,j) = nanmean(output(j).GrT,2);
    meanGrowthRateW(:,j) = nanmean(output(j).GrW,2); 
end

% locate the simulation with the highest correlation with the actual chronology
bestSimulation = find(R0==max(R0)); bestSimulation = bestSimulation(1);

%% create the primary figure

myColormap = [... % 'Reds' from ColorBrewer
    1.0000    0.9608    0.9412
    0.9961    0.8784    0.8235
    0.9882    0.7333    0.6314
    0.9882    0.5725    0.4471
    0.9843    0.4157    0.2902
    0.9373    0.2314    0.1725
    0.7961    0.0941    0.1137
    0.6471    0.0588    0.0824
    0.4039         0    0.0510];

figure(2); clf;
subplot(2,1,1)
ex2 = plot([syear:eyear],zscore(outputt2),'color',[1 0.7 0.7],'linewidth',1); hold on
ex = plot([syear:eyear],zscore(outputt2(:,bestSimulation)),'color',[1 0 0],'linewidth',1.5); hold on
rx = plot(crn(:,1),zscore(crn(:,2)),'k','linewidth',1.5);
lx = legend([ex2(1) ex(1) rx],'ENSEMBLE','BEST','OBSERVED','location','southwest');
legend boxoff
set(lx,'Position',[0.22 0.81 0.18 0.10])
xlim([1890 2005])
title('EASTERN HEMLOCK, MOHONK, SHAWANGUNK MOUNTAINS')
xlabel('YEAR')
set(gca,'xminortick','on','yminortick','on')
text(1891,3.5,'A','fontsize',14)

subplot(2,2,3)
scatter(struct(X).data(1:NI,1), struct(X).data(1:NI,2),50,R0,'filled') 
caxis([0.3 0.6])
cbx = colorbar('location','East');
colormap(myColormap)
xlim([0 10])
ylim([11 20])
xlabel('T_{minimum}')
ylabel('T_{lower optimum}')
pos = get(cbx,'position');
set(cbx,'position',[pos(1)+0.06 pos(2) 0.03 pos(4)])
title(cbx,'r')
pos = get(gca,'position');
set(gca,'position',[pos(1) pos(2) 0.28 pos(4)])
text(0.5,19,'B','fontsize',14) %,'BackgroundColor','w')
set(gca,'xminortick','on','yminortick','on','box','on')
title('PARAMETER SAMPLING')

subplot(2,2,4)
px1 = plot(meanGrowthRate,'color',[0.8 0.8 0.8]); hold on;
px2 = plot(meanGrowthRateT,'color',[1 0.8 0.8],'linewidth',0.5);
px3 = plot(meanGrowthRateT(:,bestSimulation),'color',[1 0 0],'linewidth',1.5);
px5 = plot(meanGrowthRateW(:,bestSimulation),'color',[0 0 1],'linewidth',1.5);
px4 = plot(meanGrowthRate(:,bestSimulation),'k','linewidth',1.5); hold on;
tickday =  [1; 31; 59; 90; 120; 151; 181; 212; 243; 273; 304; 334; 365];
set(gca,'XTick',tickday(1:12)+15)
set(gca,'XTickLabel',{'JAN'; ' '; 'MAR'; ' '; 'MAY'; ' '; 'JUL '; ' '; 'SEPT'; '  '; '  NOV'; ' '},'FontSize',10)
lx2 = legend([px4(1) px3(1) px5(1)],'G','g_T','g_W','location','south'); legend boxoff; 
xlim([1 365]); ylim([0 1])
title('GROWTH RATES','FontSize',12)
xlabel('DAY OF YEAR','FontSize',12)
set(gca,'xminortick','on','yminortick','on')
text(15,0.9,'C','fontsize',14)

print -dpng mohonk_panel.png
