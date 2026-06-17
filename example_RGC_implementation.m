% Human-Calibrated Retinal Ganglion Cell (RGC) Model
% Parameters loosely fit to human data from Chichilnisky et al., 2020 bioRxiv.
% Spatial RF sizes map closely to median recorded diameters: 144, 123, 66, 48 um.

img = im2double(imread('cameraman.tif'));
[rows, cols] = size(img);

% t in seconds, 1ms steps up to 500ms
t = 0:0.001:0.25; 
n = 2; % Drop power to 2 for a quicker onset profile 

% Human Parasol: Fast peak (~22ms), moderately biphasic (weight 0.45)
% Bounding parameters to return cleanly to 0 around 80ms
T_parasol = (t/0.011).^n .* exp(-t/0.011) - 0.45 * (t/0.018).^n .* exp(-t/0.018);

% Human Midget: Snappy peak (~38ms), mostly sustained/weakly biphasic (weight 0.15)
% Completely levels out to 0 by 150ms
T_midget = (t/0.019).^n .* exp(-t/0.019) - 0.15 * (t/0.040).^n .* exp(-t/0.040);

% --- 2. Human-calibrated Spatial RF Sizes ---
% 1 pixel = ~4 um scaling factor. RF diameter ~ 4 * sigma_center.
% Standard center-to-surround sigma ratio is set to 1:3.
% Standard surround-to-center amplitude ratio is set to ~0.8.

% ON-Parasol (Median diam: ~144 um -> ~36 pixels total diam -> sigma_c = 9)
sig_c_Pon = 144 / 4 / 4; 
dog_parasol_on = fspecial('gaussian', [81 81], sig_c_Pon) - ...
                  0.80 * fspecial('gaussian', [81 81], sig_c_Pon * 3);

% OFF-Parasol (Median diam: ~123 um -> ~30 pixels total diam -> sigma_c = 7.7)
sig_c_Poff = 123 / 4 / 4;
dog_parasol_off = -(fspecial('gaussian', [81 81], sig_c_Poff) - ...
                    0.80 * fspecial('gaussian', [81 81], sig_c_Poff * 3));

% ON-Midget (Median diam: ~66 um -> ~16 pixels total diam -> sigma_c = 4.1)
sig_c_Mon = 66 / 4 / 4;
dog_midget_on = fspecial('gaussian', [41 41], sig_c_Mon) - ...
                 0.85 * fspecial('gaussian', [41 41], sig_c_Mon * 3);

% OFF-Midget (Median diam: ~48 um -> ~12 pixels total diam -> sigma_c = 3)
sig_c_Moff = 48 / 4 / 4;
dog_midget_off = -(fspecial('gaussian', [41 41], sig_c_Moff) - ...
                   0.85 * fspecial('gaussian', [41 41], sig_c_Moff * 3));


% --- 3. Compute Responses ---
% Convolve image spatially and scale by the peak amplitude of the temporal filter
m_on  = imfilter(img, dog_midget_on, 'replicate')  * max(T_midget);
m_off = imfilter(img, dog_midget_off, 'replicate') * max(T_midget);
p_on  = imfilter(img, dog_parasol_on, 'replicate')  * max(T_parasol);
p_off = imfilter(img, dog_parasol_off, 'replicate') * max(T_parasol);


% --- 4. Plotting & Verification ---
figure('Name', 'Human RGC Simulation Outputs');
subplot(2,2,1); imshow(m_on, []); title('Human ON-Midget');
subplot(2,2,2); imshow(m_off, []); title('Human OFF-Midget');
subplot(2,2,3); imshow(p_on, []); title('Human ON-Parasol');
subplot(2,2,4); imshow(p_off, []); title('Human OFF-Parasol');

figure('Name', 'Human RGC Temporal Fits');
plot(t, T_parasol, 'b', t, T_midget, 'r', 'LineWidth', 2);
yline(0, '--k');
legend('Parasol (Transient / Highly Biphasic)', 'Midget (Sustained)');
xlabel('Time (seconds)'); ylabel('Response Amplitude');
title('Approximate Temporal Tuning (from Fig 4a Human Data)');
grid on;