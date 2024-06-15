capture log close _all
capture cmdlog close
clear all 

cd "S:\whole\01_Hospitalization"
log using "log_10_tv_cox_${cdat}.log",  replace

clear all
use hosp_final, clear
	gen age=(tx_age-40)/10
	gen age65=tx_age>=65 if !mi(tx_age)
		lab var age65 "Age at Donation >=65"
		
	gen bmi=(last_pretx_bmi-25)/5
	gen obese=last_pretx_bmi>=30 if !mi(last_pretx_bmi)
		lab var obese "BMI >=30"
		
	gen egfr_pre=(ckdepi_pre-90)/10
	gen egfr90_pre=ckdepi_pre<90 if !mi(ckdepi_pre)
		lab var egfr90_pre "Pre-Donation eGFR <90"
		
	gen sbp=(last_pretx_sbp-120)/10	
	gen sbp130=last_pretx_sbp>=130 if !mi(last_pretx_sbp)
		lab var sbp130 "PRE-Don sBP >=130"
		
	gen dbp=(last_pretx_dbp-80)/10
	gen dbp80=last_pretx_dbp>=80 if !mi(last_pretx_dbp)
		lab var dbp80 "PRE-Don dBP >=80"
		
	gen income=hh_income/10000
	
	recode college_bin (0=1) (1=0), gen(not_college_bin)
		lab var not_college_bin "Not 4 year college-educated"

order wholeid s_date  firsthosp_yr hosp_bin  new_post_htn_yr

//generate duplicate row for those with a post donation htn date
//ppl with 0 have 1 row of data 
//ppl with new_post_htn_yr>0 followed from 0 -> htn then htn -> survey/hosp
	gen needs_expanding = 1 if new_post_htn_yr	>0 ///
							& !mi(new_post_htn_yr),after(hosp_bin)
	replace needs_expanding = 0 if firsthosp_yr<new_post_htn_yr & !mi(new_post_htn_yr)
	
	expand 2 if needs_expanding==1
	sort wholeid
	bys wholeid : gen n=_n
	bys wholeid : gen N=_N
	order n N
	gen start = 0 , after(s_date)
	replace start = new_post_htn_yr if n==N & !mi(new_post_htn_yr) & N==2

	capt drop post_htn
	gen post_htn = 1 if new_post_htn_yr>0 & !mi(new_post_htn_yr) & N==n & N==2,after(hosp_bin)
   	replace post_htn = 0 if n<N
	replace post_htn = 1 if n==N & new_post_htn_yr==0
	replace post_htn = 0 if N==1 & needs_expanding==0 & new_post_htn==1
	replace post_htn = 0 if mi(new_post_htn_yr) 

	capt drop end
	gen end =.,after(start)
	replace end = min(s_date,firsthosp_yr) if n==N & N==1
	replace end = min(s_date,new_post_htn_yr) if n<N & N==2
	replace end = min(s_date,firsthosp_yr) if n==N & N==2 	
	
	gen outcome = .,after(hosp_bin)
	replace outcome = 0 if n<N
	replace outcome = 0 if hosp_bin==0
	replace outcome = 1 if hosp_bin==1 & N==n

	
	replace end=end+0.1 if end==start
	drop if end<start
	drop if s_date==.
	//bys wholeid: replace end=end+0.1 if end[_n-1]==end+0.1
	stset end , origin(start) id(wholeid) fail(outcome)
	
//full model
	stcox post_htn age female open pre_hx_htn bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin  adi_bin

//missingness
	missings report post_htn age female open pre_hx_htn bmi sbp dbp hxsmk egfr_pre race_howell income not_college_bin insurance_pre adi_bin,percent

//parsimonious model
stcox age female post_htn hxsmk i.race_howell


**#AIC
//outcome: all-hospitalization
//predictor: time varying post-donation diagnosis of HTN
stcox post_htn age female open pre_hx_htn bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin  adi_bin
estimates store A

stcox age female open post_htn hxsmk i.race_howell hxsmk egfr_pre adi_bin
estimates store B

stcox age female post_htn hxsmk i.race_howell
estimates store C


est stat A B C // model A is the lowest AIC

//Questions for Betsy and Abi
1. MG just realized how many ppl are being drop in analysis (complete case)
due to missingness and is concerned about bias in this approach
2. we need guidance on how to marry "risk factor identification" using a highly missing dataset where multiple imputations or a more parsimonious model would be more appropriate (but the latter introduces bias in a different way)
3. we could include varaibles with <5% missingness for example, but then it becomes less of a risk factor analysis.. bec like 5 variables are missing <5%
4. help
5. what is the priority for the paper (identifying the role of post-donation htn or trying to put all these highly missing variables in the model)
6. if the former, we can use a propensity score model to include more paitnets and acocunt for missingness 
7. we need guidance on the goal of the paper so Amy can write the discussion and get to  co-authors before submitting

