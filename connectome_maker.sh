# connectome_maker
# from the davis lab at duke university
# made in collaboration by dr. simon davis & amanda szymanski
# this version uses MRtrix3
# Harvard-Oxford Atlases of 100 & 471 ROIs are used

# denoise original files
dwidenoise data.nii.gz denoise_output.nii.gz -noise noise_output.nii.gz 

# skull strip denoised DWI
bet denoise_output.nii.gz denoise_output2.nii.gz -f 0.1 -F

# first step in calculating mean b values to get SNR
fslroi denoise_output2.nii.gz denoise_output3.nii.gz 1 25 # input how many diffusion directions your data has, not including the b0. In this example, there were 26 directions.

# calculate mean b values to get SNR
fslmaths -dt input denoise_output3.nii.gz -Tmean mean_b_vals.nii.gz -odt input

# calculate SNR
fslmaths -dt input mean_b_vals.nii.gz -div noise_output.nii.gz SNR_output

# dwipreprocess
dwipreproc denoise_output2.nii.gz preproc_output.nii.gz -rpe_none -pe_dir AP -fslgrad bvecs bvals -export_grad_fsl new_bvecs new_bvals

####-fslgrad is only needed if you are working with nii.gz files, not .mif####

# create an initial mask via bet
bet preproc_output.nii.gz preproc_output2.nii.gz -f 0.2 -F

# bias-field correction
dwibiascorrect -ants -mask preproc_output2_mask.nii.gz preproc_output2.nii.gz bias_output.nii.gz -fslgrad new_bvecs new_bvals

# create a better mask with the bias-corrected info
dwi2mask bias_output.nii.gz bias_output_mask.nii.gz -fslgrad new_bvecs new_bvals

# create tensor, create FA
dwi2tensor -mask bias_output_mask.nii.gz bias_output.nii.gz tensor.nii.gz -fslgrad new_bvecs new_bvals
tensor2metric tensor.nii.gz -fa FA.nii.gz -rd RD.nii.gz -ad AD.nii.gz

# get the response function
dwi2response tournier bias_output.nii.gz out.txt -fslgrad new_bvecs new_bvals

# response function for wm/gm/csf
dwi2response dhollander bias_output.nii.gz sfwm.txt gm.txt csf.txt -fslgrad new_bvecs new_bvals

# acquiring FOD
dwi2fod csd bias_output.nii.gz out.txt FOD.nii.gz -mask bias_output_mask.nii.gz -fslgrad new_bvecs new_bvals

dwi2fod msmt_csd bias_output.nii.gz sfwm.txt sfwm.nii.gz gm.txt gm.nii.gz csf.txt csf.nii.gz -fslgrad new_bvecs new_bvals

# generate the b0
fslroi bias_output.nii.gz b0.nii.gz 0 1 
bet b0.nii.gz betb0.nii.gz -f 0.1

# seeding done at random within a mask image
tckgen -seed_image bias_output_mask.nii.gz FOD.nii.gz tracks.tck -select 10M -maxlength 250 -fslgrad new_bvecs new_bvals
tcksift tracks.tck FOD.nii.gz SIFTtracks.tck -term_number 1M -force

# registration of MNI to subject space
flirt -in MNI152_T1_2mm_brain -ref betb0.nii.gz -out MNI_to_native -omat MNI_to_native.mat -bins 256 -cost corratio -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 12 -interp nearestneighbour

# registration to HOA in preparation of connectome creation
flirt -in HOAsp.nii -ref betb0.nii.gz -out b0_HOAsp -applyxfm -init MNI_to_native.mat -bins 256 -cost corratio -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 12 -interp nearestneighbour 
flirt -in HOA100_LR.nii.gz -ref betb0.nii.gz -out b0_HOA100_LR -applyxfm -init MNI_to_native.mat -bins 256 -cost corratio -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 12 -interp nearestneighbour

# generate the connectomes
tck2connectome SIFTtracks.tck b0_HOAsp.nii.gz output_471.csv 
tck2connectome SIFTtracks.tck b0_HOA100_LR.nii.gz output_100.csv

# generate input to create FA connectomes - example below uses both non-SIFTed and SIFTed tracks
tcksample tracks.tck FA.nii.gz FA_mean_tracks.csv -stat_tck mean
tcksample SIFTtracks.tck FA.nii.gz FA_mean_SIFT_tracks.csv -stat_tck mean

# 471 ROI FA connectomes (non-SIFT & SIFT)
tck2connectome tracks.tck b0_HOAsp output_FA_471.csv -scale_file FA_mean_tracks.csv -stat_edge mean
tck2connectome SIFTtracks.tck b0_HOAsp output_FA_471_SIFT.csv -scale_file FA_mean_SIFT_tracks.csv -stat_edge mean

# 100 ROI FA connectomes (non-SIFT & SIFT)
tck2connectome tracks.tck b0_HOA100_LR.nii.gz output_FA_100.csv -scale_file FA_mean_tracks.csv -stat_edge mean
tck2connectome SIFTtracks.tck b0_HOA100_LR.nii.gz output_FA_100_SIFT.csv -scale_file FA_mean_SIFT_tracks.csv -stat_edge mean


