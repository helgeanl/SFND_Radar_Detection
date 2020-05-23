%clear all
%clc;

%% Radar Specifications 
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Frequency of operation = 77GHz
% Max Range = 200m
% Range Resolution = 1 m
% Max Velocity = 100 m/s
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%speed of light = 3e8
%% User Defined Range and Velocity of target
% *%TODO* :
% define the target's initial position and velocity. Note : Velocity
% remains contant
r0 = 100;                              % [m] Initial position in front of RADAR
v0 = 50;                              % [m/s] Target velocity



%% FMCW Waveform Generation

% *%TODO* :
%Design the FMCW waveform by giving the specs of each of its parameters.
% Calculate the Bandwidth (B), Chirp Time (Tchirp) and Slope (slope) of the FMCW
% chirp using the requirements above.



%Operating carrier frequency of Radar 
fc= 77e9;                           % [Hz] carrier freq
c=3e8;                              % [m/s] Speed of light
wavelength = c / fc;                % [m] 
range_res = 1;                      % [m] Range resolution
range_max = 200;                    % [m] Max range
v_max = 100;                        % [m/s] Max velocity
Bsweep = c / (2*range_res);         % [Hz] Sweep of chirp
Tchirp = 5.5 * 2 * range_max / c;   % [s] Chirp time
slope = Bsweep / Tchirp;            % Slope of chirp
                                                          
%The number of chirps in one sequence. Its ideal to have 2^ value for the ease of running the FFT
%for Doppler Estimation. 
Nd=128;                   % #of doppler cells OR #of sent periods % number of chirps

%The number of samples on each chirp. 
Nr=1024;                  %for length of time OR # of range cells

% Timestamp for running the displacement scenario for every sample on each
% chirp
t=linspace(0,Nd*Tchirp,Nr*Nd); %total time for samples


%Creating the vectors for Tx, Rx and Mix based on the total samples input.
Tx=zeros(1,length(t)); %transmitted signal
Rx=zeros(1,length(t)); %received signal
Mix = zeros(1,length(t)); %beat signal

%Similar vectors for range_covered and time delay.
r_t=zeros(1,length(t));
td=zeros(1,length(t));


%% Signal generation and Moving Target simulation
% Running the radar scenario over the time. 

for i=1:length(t)         
    
    % *%TODO* :
    %For each time stamp update the Range of the Target for constant velocity. 
    r_t(i) = r0 + v0*t(i);
    td(i) = 2*r_t(i)/c;
    
    % *%TODO* :
    %For each time sample we need update the transmitted and
    %received signal. 
    Tx(i) = cos(2*pi *(fc * t(i) + slope*t(i)^2 / 2));
    Rx (i)= cos(2*pi *(fc * (t(i) - td(i)) + slope*(t(i) - td(i))^2 / 2));
    
    % *%TODO* :
    %Now by mixing the Transmit and Receive generate the beat signal
    %This is done by element wise matrix multiplication of Transmit and
    %Receiver Signal
    Mix(i) = Tx(i).*Rx(i);
    
end

%% RANGE MEASUREMENT


 % *%TODO* :
%reshape the vector into Nr*Nd array. Nr and Nd here would also define the size of
%Range and Doppler FFT respectively.
X = reshape(Mix, [Nr,Nd]);
 % *%TODO* :
%run the FFT on the beat signal along the range bins dimension (Nr) and
%normalize.
range_fft = fft(X(:,1),Nr);

 % *%TODO* :
% Take the absolute value of FFT output
range_fft = abs(range_fft);
range_fft = range_fft./max(range_fft);

 % *%TODO* :
% Output of FFT is double sided signal, but we are interested in only one side of the spectrum.
% Hence we throw out half of the samples.
range_fft = range_fft(1:Nr/2-1);

%plotting the range

figure(1);clf(1);
% subplot(2,1,1)

% *%TODO* :
% plot FFT output 
R = (c*Tchirp*f)/(2*Bsweep);
plot(range_fft) 
xlabel('Range (m)')
ylabel('|P|')
title('Range from First FFT');
axis ([0 200 0 1]);



%% RANGE DOPPLER RESPONSE
% The 2D FFT implementation is already provided here. This will run a 2DFFT
% on the mixed signal (beat signal) output and generate a range doppler
% map.You will implement CFAR on the generated RDM


% Range Doppler Map Generation.

% The output of the 2D FFT is an image that has reponse in the range and
% doppler FFT bins. So, it is important to convert the axis from bin sizes
% to range and doppler based on their Max values.

Mix_2d=reshape(Mix,[Nr,Nd]);

% 2D FFT using the FFT size for both dimensions.
sig_fft2 = fft2(Mix_2d,Nr,Nd);

% Taking just one side of signal from Range dimension.
sig_fft2 = sig_fft2(1:Nr/2,1:Nd);
sig_fft2 = fftshift (sig_fft2);
RDM = abs(sig_fft2);
RDM = 10*log10(RDM) ;

%use the surf function to plot the output of 2DFFT and to show axis in both
%dimensions
doppler_axis = linspace(-100,100,Nd);
range_axis = linspace(-200,200,Nr/2)*((Nr/2)/400);
figure(2),clf(2), surf(doppler_axis,range_axis,RDM);
xlabel('Doppler Velocity [m/s]')
ylabel('Distance [m]')


%% CFAR implementation

%Slide Window through the complete Range Doppler Map

% *%TODO* :
%Select the number of Training Cells in both the dimensions.
Tr = 12;
Td = 6;

% *%TODO* :
%Select the number of Guard Cells in both dimensions around the Cell under 
%test (CUT) for accurate estimation
Gr = 6;
Gd = 3;

% *%TODO* :
% offset the threshold by SNR value in dB
offset = 8;

% Initialize vecor for signal after thresholding
RDM_filtered = RDM;

% *%TODO* :
%Create a vector to store noise_level for each iteration on training cells
noise_level = zeros(1,1);


% *%TODO* :
%design a loop such that it slides the CUT across range doppler map by
%giving margins at the edges for Training and Guard Cells.
%For every iteration sum the signal level within all the training
%cells. To sum convert the value from logarithmic to linear using db2pow
%function. Average the summed values for all of the training
%cells used. After averaging convert it back to logarithimic using pow2db.
%Further add the offset to it to determine the threshold. Next, compare the
%signal under CUT with this threshold. If the CUT level > threshold assign
%it a value of 1, else equate it to 0.


% Use RDM[x,y] as the matrix from the output of 2D FFT for implementing
% CFAR
% Determine the number of Training cells for each dimension. Similarly, pick the number of guard cells.

training_cells = (2*Tr+2*Gr+1)*(2*Td+2*Gd+1) - (2*Gr+1)*(2*Gd+1);

for i = 1:Nr/2
    for j = 1:Nd
        % Set edge not checked by CUT to zero
        if(i <= Tr+Gr || i >= Nr/2 - Tr-Gr)
            RDM_filtered(i,j) = 0;
            continue
        end
        if(j <= Td+Gd || j >= Nd - Td-Gd)
            RDM_filtered(i,j) = 0;
            continue
        end
    
        % Estimate the noise level by averaging the signal strength in the
        % training cells
        noise_total_area = sum(db2pow(RDM(i - Tr - Gr: i+Tr + Gr, j - Td - Gd:j+ Td + Gd)),'all');
        noise_guard_area = sum(db2pow(RDM(i - Gr: i + Gd, j-Gd:j+Gd)),'all');   
        noise_level = (noise_total_area - noise_guard_area)/  training_cells;
           
        threshold = pow2db(noise_level) + offset;

        if (RDM(i, j) <= threshold)
            RDM_filtered(i,j) = 0;
        else 
            RDM_filtered(i,j) = 1;
        end    
    end
end


% *%TODO* :
% The process above will generate a thresholded block, which is smaller 
%than the Range Doppler Map as the CUT cannot be located at the edges of
%matrix. Hence,few cells will not be thresholded. To keep the map size same
% set those values to 0. 



% *%TODO* :
%display the CFAR output using the Surf function like we did for Range
%Doppler Response output.
doppler_axis = linspace(-100,100,Nd);
range_axis = linspace(-200,200,Nr/2)*((Nr/2)/400);
figure(3),clf(3),surf(doppler_axis,range_axis,RDM_filtered);
xlabel('Doppler Velocity [m/s]')
ylabel('Distance [m]')
colorbar;


 
 