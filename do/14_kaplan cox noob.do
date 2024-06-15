capture log close _all
capture cmdlog close
clear all 

cd "S:\whole\01_Hospitalization"
log using "log_14_kaplan_cox_noob_${cdat}.log",  replace

clear all
use hosp_final_noob, clear
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


//censor those who were hospitalized or up to their survey date
egen studytime = rowmin(firsthosp_yr s_date)
	unique wholeid if (hosp_bin==1 & mi(firsthosp_yr)) | (mi(s_date) & mi(firsthosp_yr))
	drop if hosp_bin==1 & mi(firsthosp_yr) //n=69/2251
	drop if mi(studytime) //n=1
	
//replace those with years=0 to 0.1 to be included in the model
replace studytime=0.1 if studytime==0 //n=41

//setup and declare the data to be failure-time data
stset studytime, failure(hosp_bin==1) 


**# Cox Proportional Hazard Model (predonation)
//fit cox model
stcox age female pre_hx_htn bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin insurance_pre adi_bin

