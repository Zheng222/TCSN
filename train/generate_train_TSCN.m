clear; close all;
%% settings
folder = '291-aug/';  % 291 augment dataset
savepath = 'train_hdf5/train_x2.h5';  % save filename
size_input = 35; % 35 | 25 | 19
size_label = 70; % 70 | 75 | 76
scale = 2; % upsacling factor 3 | 4
stride = 35; % subimages sampling stride 35 | 25 | 19

%% initialization
data = zeros(size_input, size_input, 1, 1);
label = zeros(size_label, size_label, 1, 1);
count_input = 0;
count_label = 0;

%% generate data
filepaths=dir(fullfile(folder,'*.bmp'));

for i = 1 :length(filepaths)
    
    image = imread(fullfile(folder, filepaths(i).name));
    if size(image,3) == 1
        continue;
    end
    
    image = rgb2ycbcr(image);
    image = im2double(image(:, :, 1)); % uint8 to double, ranges from [16/255, 235/255]

    im_label = modcrop(image, scale); % high resolution subimage
    im_input = imresize(im_label, 1/scale, 'bicubic'); % low resolution subimage
    im_bic = imresize(im_input,scale,'bicubic'); % interpolated low resolution subimage
    
    [hei,wid] = size(im_input); % LR subimage size
    [hei_label,wid_label] = size(im_label);% HR subimage size
    stride_label = stride * scale;
    % two-step cut
    % data
    for x = 1 : stride : hei - size_input + 1
        for y = 1 : stride : wid - size_input + 1           
            subim_input = im_input(x : size_input + x - 1, y : size_input + y - 1);   
            count_input = count_input + 1;
            data(:, :, 1, count_input) = subim_input;
        end
        
    end
    
    % label
    for x = 1 : stride_label : hei_label -size_label + 1
        for y = 1 : stride_label : wid_label -size_label +1
            locx=x;
            locy=y;
            subim_label = im_label(locx:size_label+locx-1, locy:size_label+locy-1);
            count_label = count_label+1;
            label(:, :, 1, count_label) = subim_label;
        end
    end
    
end

assert(count_label==count_input, 'Number of samples should be matched between data and labels');
count = count_label;

order = randperm(count);
data = data(:, :, 1, order);
label = label(:, :, 1, order);

%% writing to HDF5
chunksz = 64; % chunksize
created_flag = false;
totalct = 0;

for batchno = 1:floor(count/chunksz)
    last_read = (batchno-1)*chunksz;
    batchdata = data(:,:,1,last_read+1:last_read+chunksz); 
    batchlabs = label(:,:,1,last_read+1:last_read+chunksz);

    startloc = struct('dat',[1,1,1,totalct+1], 'lab', [1,1,1,totalct+1]);
    curr_dat_sz = store2hdf5(savepath, batchdata, batchlabs, ~created_flag, startloc, chunksz); 
    created_flag = true;
    totalct = curr_dat_sz(end);
end
h5disp(savepath);