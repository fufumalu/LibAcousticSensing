function [] = WinkingCallback_s( server, type, data )
%SERVERDEVCALLBACK Summary of this function goes here
    global USER_FIG_TAG; USER_FIG_TAG = 'USER_FIG_TAG';
    global Hd_bandpass;
    global Hd_lowpass;
    global cosbuffer;
    global sinbuffer;
    global h;
    global dsize;
    global tracesize;
    global chsize;
    global BPData;
    global QData;
    global IData;
    global LPQData;
    global LPIData;
    global RData;
    global r;
    global H1;
    global H2;
    global H3;
    global flag;
    global count; %Plot when count equal 120;
 
    if type == server.CALLBACK_TYPE_ERROR,
        fprintf(2, '[ERROR]: get the error callback data = %s', data);
        return;
    end

    M = [
     0.116616,0.0335961,-0.285324,-0.207823,0.184779,0.0138265,-0.119163,-0.0949667,-0.0217708,0.174227,-0.238387,0.0160703,0.29151,0.0175258,0.214008,0.189812;
     0.108854,0.03396,0.0888417,-0.0494239,-0.31322,0.0175864,0.17738,-0.0418436,-0.00576109,0.0154639,0.385385,-0.115525,-0.212553,0.149485,-0.0742874,0.144936;
     0.180958,0.179018,0.0897513,-0.0676774,-0.0154033,-0.150152,-0.100667,0.136568,-0.123226,-0.11134,-0.104184,0.255306,0.000970285,-0.0762887,0.158399,-0.0788357;
     -0.0987113,0.143299,0.150773,0.174485,-0.0868557,-0.102577,-0.0863402,-0.0783505,0.180155,-0.0677835,-0.046134,-0.0347938,0.191495,-0.0719072,-0.0822165,0.159794;
     0.151289,-0.106701,0.150773,0.174485,0.163144,-0.102577,-0.0863402,-0.0783505,-0.0698454,0.182216,-0.046134,-0.0347938,-0.0585052,0.178093,-0.0822165,-0.0902062;
     -0.0987113,0.143299,-0.0992268,0.174485,0.163144,0.147423,-0.0863402,-0.0783505,-0.0698454,-0.0677835,0.203866,-0.0347938,-0.0585052,-0.0719072,0.167783,-0.0902062;
     -0.0987113,-0.106701,0.150773,-0.0755155,0.163144,0.147423,0.16366,-0.0783505,-0.0698454,-0.0677835,-0.046134,0.215206,-0.0585052,-0.0719072,-0.0822165,0.159794;
     0.122135,-0.1151,-0.0278957,0.22644,-0.13305,0.143966,0.193451,0.195391,-0.0644027,-0.11134,0.0134627,-0.0388114,0.118617,-0.0762887,-0.135719,-0.137659;
     -0.0676168,0.151607,-0.264099,-0.167071,0.333839,-0.100061,0.0597332,0.134627,0.17071,0.0154639,-0.261674,0.0021225,0.140388,0.149485,0.0433596,-0.0315343;
     -0.118678,-0.142874,0.244087,-0.0313523,-0.28581,0.190297,0.0573074,0.140327,0.213523,0.174227,0.232201,-0.1604,-0.237902,0.0175258,0.0375379,-0.0454821;
     -0.0676168,0.151607,-0.264099,-0.167071,0.333839,-0.100061,0.0597332,0.134627,0.17071,0.0154639,-0.261674,0.0021225,0.140388,0.149485,0.0433596,-0.0315343
     ];
%--------------------------------------------------------------------------
% 1.2 init filter
%--------------------------------------------------------------------------
% 1.2.1 init bandpass filter 18k-22k
%--------------------------------------------------------------------------
    if type == server.CALLBACK_TYPE_INIT,
       H1 = zeros(120,1);
       H2 = zeros(120,1);
       H3 = zeros(120,1);
       count = 0;
       FS = 48000;
       SIGNAL_FREQ = 20000;
       cosbuffer = zeros(500,1);
       sinbuffer = zeros(500,1);
       for i = 1:1:500
            cosbuffer(i) = cos(2*pi*(i-1)*SIGNAL_FREQ/FS)*sqrt(2);
            sinbuffer(i) = -1*sin(2*pi*(i-1)*SIGNAL_FREQ/FS)*sqrt(2);
       end
       Fs = 48000;  % Sampling Frequency
       Fstop1 = 17000;       % First Stopband Frequency
       Fpass1 = 18000;       % First Passband Frequency
       Fpass2 = 22000;       % Second Passband Frequency
       Fstop2 = 23000;       % Second Stopband Frequency
       Astop1 = 60;          % First Stopband Attenuation (dB)
       Apass  = 1;           % Passband Ripple (dB)
       Astop2 = 80;          % Second Stopband Attenuation (dB)
       match  = 'stopband';  % Band to match exactly

    % Construct an FDESIGN object and call its BUTTER method.
       h  = fdesign.bandpass(Fstop1, Fpass1, Fpass2, Fstop2, Astop1, Apass, ...
                      Astop2, FS);
       Hd_bandpass = design(h, 'butter', 'MatchExactly', match);
%--------------------------------------------------------------------------
% 1.2.2 init lowpass filter 2k
%--------------------------------------------------------------------------
       Fpass = 2000;        % Passband Frequency
       Fstop = 3000;        % Stopband Frequency
       Apass = 1;           % Passband Ripple (dB)
       Astop = 80;          % Stopband Attenuation (dB)
       match = 'stopband';  % Band to match exactly

    % Construct an FDESIGN object and call its BUTTER method.
       h  = fdesign.lowpass(Fpass, Fstop, Apass, Astop, Fs);
       Hd_lowpass = design(h, 'butter', 'MatchExactly', match);

       LINE_CNTS = [1,1]; % size of it is the number of figure axes, and the number in it is the number of lines per axe

       createUI(server, USER_FIG_TAG, data, LINE_CNTS);
%--------------------------------------------------------------------------
% 2. data processing and update figures
%--------------------------------------------------------------------------
% 2.1 bandpass filtering && demodulation && lowpass filtering
%--------------------------------------------------------------------------
  elseif type == server.CALLBACK_TYPE_DATA          
       dsize = size(data,1);
       tracesize = size(data,2);
       chsize = size(data,3);
       BPData = zeros(dsize,tracesize,chsize);
       QData = zeros(dsize,tracesize,chsize);
       IData = zeros(dsize,tracesize,chsize);
       LPQData = zeros(dsize,tracesize,chsize);
       LPIData = zeros(dsize,tracesize,chsize);
       RData = zeros(dsize,tracesize,chsize);
       for chIdx = 1:chsize
           for traIdx = 1:tracesize
               BPData(:,traIdx,chIdx) =  filter(Hd_bandpass,data(:,traIdx,chIdx));
               for DataIdx = 1:dsize
                    QData(DataIdx,traIdx,chIdx) = BPData(DataIdx,traIdx,chIdx)*cosbuffer(DataIdx);
                    IData(DataIdx,traIdx,chIdx) = BPData(DataIdx,traIdx,chIdx)*sinbuffer(DataIdx);
                    %todo:�õ���ʵ���鲿�����Խ���virtualpath�����
               end
               LPQData(:,traIdx,chIdx) = filter(Hd_lowpass,QData(:,traIdx,chIdx));
               LPIData(:,traIdx,chIdx) = filter(Hd_lowpass,IData(:,traIdx,chIdx));
               RData(:,traIdx,chIdx) = LPQData(:,traIdx,chIdx)+LPIData(:,traIdx,chIdx)*1i;
           end
       end
%--------------------------------------------------------------------------
% 2.2 calculating the h
       r = zeros(26,tracesize,chsize);
       h = zeros(10,tracesize,chsize);
       for chIdx = 1:chsize
            for traIdx = 1:tracesize
                  for i = 1:1:26
                       r(i,traIdx,chIdx) = r(i,traIdx,chIdx)+RData(12*i-5);
                       r(i,traIdx,chIdx) = r(i,traIdx,chIdx)+RData(12*i-4);
                       r(i,traIdx,chIdx) = r(i,traIdx,chIdx)/2.0;
                  end
                  for i = 1:1:10
                      for j = 1:1:16
                           h(i,traIdx,chIdx) = h(i,traIdx,chIdx)+ r(i+10,traIdx,chIdx)* M(i,j);
                      end
                  end
            end
       end
       [H1,H2,H3,count,flag] = calH(H1,H2,H3,h,count,flag);
        %xlswrite('h.xls',h);
        % update line1: data 
        check1 = findobj('Tag','check01');
        if check1.Value == 1
            for chIdx = 1:1
                line = findobj('Tag',sprintf('line01_%02d',chIdx));
                dataToPlot = H2(:,1);
                set(line, 'yData', dataToPlot); % only show the 1st ch
            end
        end

        % update line2: detected peaks
        check2 = findobj('Tag','check02');
        if check2.Value == 1
            for chIdx = 1:1 % TODO: based on channel
                line = findobj('Tag',sprintf('line02_%02d',chIdx));
                dataToPlot = H3(:,1);
                set(line, 'yData', dataToPlot); % only show the 1st ch
            end
        end
    end
end

function createUI(server, figTag, data, lineCnts)
    % lineCnts is the number of lines per figure
    %global PS;
    
    %PLOT_AXE_IN_WIDTH = 270;
    PLOT_AXE_OUT_WIDTH = 290;
    PLOT_AXE_CNT = length(lineCnts);
    
    server.userfig = figure(...
                    'Name', 'Callback', ...
                    'Position',[500,250,550+PLOT_AXE_OUT_WIDTH*(PLOT_AXE_CNT-1),330], ...
                    'Toolbar','none', ...
                    'MenuBar','none', ...
                    'Tag', figTag);
    set(server.userfig, 'UserData', server); % attached the server object to fig property for future reference 
    
    h_panel2 = uipanel(server.userfig,'Units','pixels','Position',[15,15,520+PLOT_AXE_OUT_WIDTH*(PLOT_AXE_CNT-1),300]);
    
    UPDATE_LABELS = {'H2', 'H3'};
    X_LABELS = {'sample', 'meter'};
    for i = 1:PLOT_AXE_CNT
        uicontrol(h_panel2, 'Style','checkbox','String',UPDATE_LABELS{i},'Value',0,'Position',[(220+PLOT_AXE_OUT_WIDTH*(i-1)),280,200,20], 'Tag',sprintf('check%02d',i));
        
        server.axe = axes('Parent',h_panel2,'Units','pixels','Position',[220+PLOT_AXE_OUT_WIDTH*(i-1),30,270,250]);
        hold on;
        ylim([-6,6]);
        for j = 1:lineCnts(i)
            plot(server.axe, data(:,1),'Tag',sprintf('line%02d_%02d',i,j),'linewidth',2); % only show the 1st ch
        end
        hold off;
        xlabel(X_LABELS{i})
        legend(arrayfun(@(x) sprintf('%d',x), 1:lineCnts(i),'uni',false).');
    end
end

function [H1,H2,H3,count,flag] = calH(H1,H2,H3,h,count,flag)
    if count == 0 
        H1(count+1) = h(1,1,1);
        flag = false;
        count = count+1;
    elseif count<120
        H1(count+1)=h(1,1,1);
        H2(count) = angle(H1(count+1)-H1(count));
        H3(count) = abs(H1(count+1)-H1(count));
        count = count + 1;
    else
        H1(1:119) = H1(2:120);
        H2(1:118) = H2(2:119);
        H3(1:118) = H3(2:119);
        H2(119) = angle(h(1,1,1)-H1(120));
        H3(119) = abs(h(1,1,1)-H1(120));
        H1(120) = h(1,1,1);
        if(flag == false)
            %matwrite('h.mat',H1);
            save h.mat H1;
            flag = true;
        end
    end
end
