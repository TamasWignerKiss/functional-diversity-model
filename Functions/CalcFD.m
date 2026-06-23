function [DFD, IFD, IFDS, SDI] = CalcFD(agents)
%This function calculates DFD and IFD values (as well as IFDS, which is intrapersonal diversity score, the agent-level measure of their functional
%diversity). Calculations are based on Bunderson and Sutcliffe, 2002, Academy of Management Journals paper.
%
%Usage: [DFD, IFD, IFDS, SDI] = CalcFD(agents)
%
% Author: (anonymized for double-anonymous peer review)

%% Calculate DFD, dominant function diversity
maxDFD = 1-1/size(agents, 2); %This is the maxmial value DFD can take.
[~, I] = max(agents, [], 2);
T = tabulate(I);
DFD = 1 - sum((T(:,3)/100).^2); %This is the first formula in the Bunderson & Sutcliffe, 2002 paper
DFD = DFD/maxDFD; %This is the normalization they mention on page 885 below the formula

%% Calculate IFD, intrapersonal functional diversity
% First calculate IFDS
IFDS = 1 - sum((agents./sum(agents,2)).^2, 2);
%Normalizing factor
maxIFDS = 1-1/size(agents, 2); %Maximal value IFDS can take
IFDS = IFDS/maxIFDS;
% Second, mean IFDSs across agents to get IFD
IFD = mean(IFDS);

%% Calculate SDI, score diversity index
SC = sum(agents)/size(agents, 1); %This is how much a score is covered
nSC = SC/sum(SC);
maxSDI = 1-1/size(agents, 2);
SDI = (1 - sum(nSC.^2)) / maxSDI;

end

