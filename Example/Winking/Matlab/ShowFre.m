function [  ] = ShowFre( y ,L)
%UNTITLED2 �˴���ʾ�йش˺�����ժҪ
%   �˴���ʾ��ϸ˵��
Fs = 48000;
f = Fs*(0:(L/2))/L;
Y1 = fft(y);
P21 = abs(Y1/L);
P11 = P21(1:L/2+1);
P11(2:end-1) = 2*P11(2:end-1);
plot(f,P11)

end

