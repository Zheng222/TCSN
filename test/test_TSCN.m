clear;clc;
% caffe.set_mode_cpu();
caffe.set_mode_gpu();
caffe.set_device(0);  % gpu_id
caffe.reset_all();

addpath('./evaluation_func/');
addpath('./evaluation_func/matlabPyrTools-master/');

model='TSCN_x2_deploy.prototxt';
% model='TSCN_x3_deploy.prototxt';
% model='TSCN_x4_deploy.prototxt';

weights='caffemodel/TSCN_x2.caffemodel';
% weights='caffemodel/TSCN_x3.caffemodel';
% weights='caffemodel/TSCN_x4.caffemodel';

net=caffe.Net(model,weights,'test');
test_dataset='Set5';  % Set5 | Set14 | B100 | Urban100

testfolder=['test_data/' test_dataset '/'];
up_scale=2;  % 2 | 3 | 4

savepath = 'results/';
folderResultCur = fullfile(savepath,[test_dataset,'_x',num2str(up_scale)]);
if ~exist(folderResultCur,'file')
    mkdir(folderResultCur);
end

if strcmp(test_dataset,'Set5') || strcmp(test_dataset,'Set14')
    filepaths=dir(fullfile(testfolder,'*.bmp'));
else
    filepaths=dir(fullfile(testfolder,'*.jpg'));
end

psnr_bic=zeros(length(filepaths),1);
psnr_tscn=zeros(length(filepaths),1);

ssim_bic=zeros(length(filepaths),1);
ssim_tscn=zeros(length(filepaths),1);

ifc_bic=zeros(length(filepaths),1);
ifc_tscn=zeros(length(filepaths),1);

time_tscn=zeros(length(filepaths),1);

for i=1:length(filepaths)
    %% read groud truth image
    [add,imname,type]=fileparts(filepaths(i).name);
    im=imread([testfolder imname type]);
    dimension=size(im,3);
    %% work on illuminance only
    if size(im,3) > 1
        im_ycbcr=rgb2ycbcr(im);
        im=im_ycbcr(:,:,1);
        im_cb=im_ycbcr(:,:,2);
        im_cr=im_ycbcr(:,:,3);
        im_cb=modcrop(im_cb,up_scale);
        im_cr=modcrop(im_cr,up_scale);
        im_cb_=shave(imresize(imresize(im_cb,1/up_scale,'bicubic'),up_scale,'bicubic'),[up_scale,up_scale]);
        im_cr_=shave(imresize(imresize(im_cr,1/up_scale,'bicubic'),up_scale,'bicubic'),[up_scale,up_scale]);
    end
    im_gnd = modcrop(im,up_scale);
    im_gnd = single(im_gnd) / 255;
    im_l = imresize(im_gnd,1/up_scale,'bicubic');
    
    
    %% bicubic interpolation
    im_b=imresize(im_l,up_scale,'bicubic');
      
    %% reinforce_net
    tic
    
    im_input=permute(im_l,[2,1,3]);
    net.blobs('data').reshape([size(im_input),1,1]);
    net.reshape();
    net.blobs('data').set_data(im_input); 
    net.forward_prefilled();
    im_result=net.blobs('sum').get_data();
    im_h=im_result';
    
    time_tscn(i)=toc;


    %% remove border   
    im_h=shave(uint8(im_h*255),[up_scale,up_scale]);
    im_gnd=shave(uint8(im_gnd*255),[up_scale,up_scale]);
    im_b=shave(uint8(im_b*255),[up_scale,up_scale]);
    
    %% compute PSNR
    psnr_bic(i)=compute_psnr(im_gnd,im_b);
    psnr_tscn(i)=compute_psnr(im_gnd,im_h);
    
    %% compute SSIM
    ssim_bic(i)=ssim_index(im_gnd,im_b);
    ssim_tscn(i)=ssim_index(im_gnd,im_h);
    
    %% compute IFC
    ifc_bic(i)=ifcvec(double(im_gnd),double(im_b));
    ifc_tscn(i) = ifcvec(double(im_gnd),double(im_h));

    if dimension>1
        imwrite(ycbcr2rgb(cat(3,im_h,im_cb_,im_cr_)),fullfile(folderResultCur,[imname,'_x',num2str(up_scale),'.png']));
    else
        imwrite(im_h,fullfile(folderResultCur,[imname,'_x',num2str(up_scale),'.png']));
    end
    save(fullfile(folderResultCur,['PSNR_',test_dataset,'_x',num2str(up_scale),'.mat']),'psnr_tscn');
    save(fullfile(folderResultCur,['SSIM_',test_dataset,'_x',num2str(up_scale),'.mat']),'ssim_tscn');
    save(fullfile(folderResultCur,['TIME_',test_dataset,'_x',num2str(up_scale),'.mat']),'time_tscn')
end

fprintf('Mean PSNR for Bicubic: %f dB\n', mean(psnr_bic));
fprintf('Mean PSNR for TSCN: %f dB\n', mean(psnr_tscn)); 

fprintf('Mean SSIM for Bicubic: %f \n', mean(ssim_bic));
fprintf('Mean SSIM for TSCN: %f \n', mean(ssim_tscn));

fprintf('Mean IFC for Bicubic: %f \n', mean(ifc_bic)); 
fprintf('Mean IFC for TSCN: %f \n', mean(ifc_tscn)); 

fprintf('Mean Time for TSCN: %f \n', mean(time_tscn));
