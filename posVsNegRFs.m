im = imread('kids.tif');
im = im2double(im2gray(im));
im = im - mean(im, 'all');

hsize = 20;
sigma = 2;
hCenter = fspecial("gaussian", hsize, sigma);
hSurround = fspecial("gaussian",hsize, sigma * 3);
hCenter = hCenter / sum(hCenter);
hSurround = hSurround / sum(hSurround);
DoGON  =  1.5*hCenter - .5 * hSurround;
DoGOFF = -DoGON;

% Apply the Difference of Gaussian filter to the image
outON = max(0,imfilter(im, DoGON, 'replicate'));
outOFF = max(0, imfilter(im, DoGOFF, 'replicate'));

figure(1); clf; imshow([im outON outOFF],[-.2 .2]);colormap(hsv); colorbar;
figure(2); clf; histogram(outON); hold on; histogram(outOFF);

