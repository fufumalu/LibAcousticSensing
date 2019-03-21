%==========================================================================
% 2017/03/29: An example to detect nearby objects by sounds
%           : it can estiamte the distance to the object as well
%==========================================================================
close all;
import edu.umich.cse.yctung.*
JavaSensingServer.closeAll(); % close all previous open socket
SERVER_PORT = 50005; % remember to diable firewall for this port

%--------------------------------------------------------------------------
% 1. signal settings
%--------------------------------------------------------------------------
FS = 48000;                 % sample rate (Hz)
PERIOD = 600;              % period of one repetition of sensing
SIGNAL_LEN = 312;           % signal length (shorter than period) 
SIGNAL_FREQ = 20000;
%CHIRP_FREQ_START = 18000;   % signal min freq (Hz)
%CHIRP_FREQ_END = 24000;     % signal max freq (Hz)
APPLY_FADING_TO_SIGNAL = 1; % fade in/out of the singal for being inaudible
FADING_RATIO = 0.2;         % ratio of singals being "faded"
REPEAT_CNT = 20*60*4;       % total repetition of signal to play
SIGNAL_GAIN = 0.8;          % gain to scale signal

%--------------------------------------------------------------------------
% 2. build sensing signal and AudioSource object
%--------------------------------------------------------------------------
signal = zeros(600, 1);
%signal_low = zeros(600, 1);
%time = (0:SIGNAL_LEN-1)./FS;
       Fpass = 2000;        % Passband Frequency
       Fstop = 3000;        % Stopband Frequency
       Apass = 1;           % Passband Ripple (dB)
       Astop = 80;          % Stopband Attenuation (dB)
       match = 'stopband';  % Band to match exactly

    % Construct an FDESIGN object and call its BUTTER method.
       h  = fdesign.lowpass(Fpass, Fstop, Apass, Astop, FS);
       Hd_lowpass = design(h, 'butter', 'MatchExactly', match);

%int8_t           traseq[TRANUM] = {0,0,1,0,0,1,0,1,1,1,0,0,0,0,1,0,0,0,1,0,0,1,0,1,1,1}; //training sequence
traseq = [0,0,1,0,0,1,0,1,1,1,0,0,0,0,1,0,0,0,1,0,0,1,0,1,1,1];
for i = 1:1:26
    %my method
    for j = 1:1:12
        
        if(traseq(i) == 0)
            signal((i-1)*12+j) = -1;
        end
        if(traseq(i) == 1)
            signal((i-1)*12+j) = 1;
        end
        
    end
    %{
    if(traseq(floor(i/12)+1) == 0)
        signal(i) = -1;
    else
        signal(i) = 1;
    end
    %}
end
cosbuffer = zeros(600,1);
sinbuffer = zeros(600,1);
for i = 1:1:600
    cosbuffer(i) = cos(2*pi*(i-1)*SIGNAL_FREQ/FS)*sqrt(2);
    sinbuffer(i) = sin(2*pi*(i-1)*SIGNAL_FREQ/FS)*sqrt(2);
end

%signal_low = filter(Hd_lowpass,signal);
signal_mod = zeros(600,1);
for i = 1:1:600
    signal_mod(i) = signal(i)*cosbuffer(i);
end
%BandPass filter 18k-22k
%------------------------------------------------------------------------
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
%-------------------------------------------------------------------------

signal_send = filter(Hd_bandpass,signal_mod);

%signal(1:SIGNAL_LEN) = 
%chirp(time, CHIRP_FREQ_START, time(end), CHIRP_FREQ_END);
if APPLY_FADING_TO_SIGNAL == 1, % add fadding if necessary (make it inaudible but lose some SNR)
    signal(1:SIGNAL_LEN) = ApplyFadingInStartAndEndOfSignal(signal(1:SIGNAL_LEN), FADING_RATIO);
end
save signal_send.mat signal;
as = AudioSource('WinkingSound', signal, FS, REPEAT_CNT, SIGNAL_GAIN);

%--------------------------------------------------------------------------
% 3. parse settings (later used in ObjectDetectorCallback)
%--------------------------------------------------------------------------
%global PS; PS = struct(); % parse setting, easy for the callback to get
%PS.FS = FS;
%PS.detectRangeStart = SIGNAL_LEN/2; % for remove unnecessary singals in convolution
%PS.detectRangeEnd = 1800; % should be larger than CHIRP_LEN/2
%PS.detectEnabled = 0;
%PS.detectRef = 0;
%PS.signalToCorrelate = signal(SIGNAL_LEN:-1:1); % reverse the chirp is the optimal matched filter to detect chirp singals

%--------------------------------------------------------------------------
% 4. build sensing server
%--------------------------------------------------------------------------
global ss; % TODO: find a better way instead of using a global variable
ss = SensingServer(SERVER_PORT, @WinkingCallback, SensingServer.DEVICE_AUDIO_MODE_PLAY_AND_RECORD, as);
ss.startSensingAfterConnectionInit = 0; % avoid auto sensing
