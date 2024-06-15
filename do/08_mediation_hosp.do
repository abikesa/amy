capture log close _all
capture cmdlog close
clear all 

cd "S:\whole\01_Hospitalization"
log using "log_08_mediation_${cdat}.log",  replace

clear all
use hosp_final, clear

//post-donation htn is the mediator
//relationship pre-donation eGFR : hosp
sem (ckdepi_pre -> hosp_bin, ) (ckdepi_pre -> post_hx_htn, ) (post_hx_htn -> hosp_bin, ), nocapslatent
medsem, indep(ckdepi_pre) med(post_hx_htn) dep(hosp_bin)

//post-donation dm is the mediator
//relationship pre-donation eGFR : hosp
sem (ckdepi_pre -> hosp_bin, ) (ckdepi_pre -> post_hx_dm, ) (post_hx_dm -> hosp_bin, ), nocapslatent
medsem, indep(ckdepi_pre) med(post_hx_dm) dep(hosp_bin)

//race is the mediator
//relationship ADI: hosp
sem (adi_bin -> hosp_bin, ) (adi_bin -> white, ) (white -> hosp_bin, ), nocapslatent
medsem, indep(adi_bin) med(white) dep(hosp_bin)

//ADI is the mediator
//relationship predonation-insurance: hosp
sem (adi_bin -> hosp_bin, ) (adi_bin -> insurance_pre, ) (insurance_pre -> hosp_bin, ), nocapslatent
medsem, indep(adi_bin) med(insurance_pre) dep(hosp_bin)