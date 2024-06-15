capture log close _all
capture cmdlog close
clear all 

cd "S:\whole\01_Hospitalization"
log using "log_12_cv_hosp_tv_cox_dm_htn_${cdat}.log",  replace

clear all
use hosp_final, clear

//creating model now for outcome of cardiovascular related hospitalization, compared to hospitalization for any
//excluding those who were never hospitalization
merge 1:1 wholeid using hosp_cv_yr, nogen keep(master match)
replace hosp_bin=hosp_cv
replace firsthosp_yr=hosp_cv_yr

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

order wholeid s_date  firsthosp_yr hosp_bin  new_post_htn_yr new_post_dm_yr

//censor those who were hospitalized or up to their survey date
egen studytime = rowmin(firsthosp_yr s_date)
	count
	unique wholeid if (hosp_bin==1 & mi(firsthosp_yr)) | (mi(s_date) & mi(firsthosp_yr))
	drop if hosp_bin==1 & mi(firsthosp_yr) //n=9/2251
	drop if mi(studytime) //n=1
	
//replace those with years=0 to 0.1 to be included in the model
replace studytime=0.1 if studytime==0 //n=5

//setup and declare the data to be failure-time data
stset studytime, failure(hosp_bin==1) 

**# Kaplan Meier
//plot the kaplan meier failure
qui sts graph, failure risktable ///
tmax(20) ///
title("Cumulative Incidence Of First Cardiovascular Related" "Hospitalization Compared to Non-CV Related" "After Live Kidney Donation", color(black)) ///
xtitle("Years Post-donation", size(med) margin(medsmall) color(black)) ///
ytitle("Proportion of CV-related Hospitalized (%)") ///
ylab(0 "0" 0.1 "10" 0.2 "20" 0.3 "30" , angle(0)) ///
xlab(1 "1" 3 "3" 5 "5" 10 "10" 15 "15" 20 "20") ///
note("Patients that reported hospitalization, but not year of CV related hospitalization, were excluded (n=9)" ///
"Patients were censored at their survey date", span  size(vsmall)) ///
graphregion(color(white))
graph export "km_survival_cv_hosp.png", as(png) width(1200) replace
graph export "km_survival_cv_hosp.tiff", as(tif) width(3000)replace

//cumulative incidence at each specified year
sts list, failure at(1 3 5 10 15 20) 


**# Cox Proportional Hazard Model (predonation)
//fit cox model
stcox age female pre_hx_htn bmi hxsmk egfr_pre i.race_howell adi_bin

//globally and by variable, does the proportional hazard hold
//can we assume that these independent variables, is their HR
estat phtest, detail

coefplot, drop(_cons) eform ///
title("Cox Regression (Baseline)" , size(large) margin(tiny) color(black)) ///
subtitle("Cardiovascular vs Non-cardiovascular Related Hospitalization") ///
xline(1, lwidth(thin) lpattern(dash) lcolor(red%70)) ///
xscale(log) ///
xlab(0.5 "0.5" 1.0 "1.0" 1.5 "1.5" 2 "2.0" 3 "3.0" 4 "4.0", labsize(small)) ///
xtitle("Hazard Ratios and 95% Confidence Intervals" , margin(medsmall)) ///
ylab(1 "Age" ///
2  "Female" ///
3 "Hypertension History" ///
4 "BMI" ///
5 "Ever Smoke" ///
6 "eGFR" ///
7 "Hispanic, Any Race" ///
8 "Non-Hispanic Black" ///
9 "Non-Hispanic Asian/Indigenous/Other" ///
10 "High Area Deprivation Index (>=38%)", labsize(2.3)) ///
mlabel format(%9.2f) mlabposition(12) mlabgap(*.5) mlabsize(2) ///
legend(off) ciopts(lwidth(*1 *5)) ///
levels(95) msym(s) mfcolor(white) ///
note("OR per 10 year increase in age at donation" ///
"OR per 5 kg/m2 increase in pre-donation body mass index (BMI)" ////
"OR per 10 ml/min/1.73 m2 increase in eGFR (CKD-EPI 2021)" ///
"Area Deprivation Index (ADI) data from the Neighborhood Atlas by the University of Wisconsin, matched by census block group" ///
"Higher ADI is associated with more disadvantage" ///
,span size(vsmall)) ///
plotregion(margin(zero)) ///
graphregion(color(white))
graph export "cox_cv_hosp_baseline.png", as(png) width(1200) replace
graph export "cox_cv_hosp_baseline.tiff", as(tif) width(3000) replace




**# Time Varying HTN & DM in Cox
//first of Post-donation HTN or DM (using new_post_htn_yr variable)
gen new_post_htn_yr_old = new_post_htn_yr,after(new_post_htn_yr)
replace new_post_htn_yr = min(new_post_htn_yr,new_post_dm_yr)

//making new_post_htn var a combo of dm + HTN
replace new_post_htn = 1 if new_post_htn==1 | new_post_dm==1

bro
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
	lab var post_htn "Post-donation HTN/DM"
	
//full model
	stcox post_htn age female open pre_hx_htn bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin  adi_bin

//missingness
	missings report post_htn age female open pre_hx_htn bmi sbp dbp hxsmk egfr_pre race_howell income not_college_bin insurance_pre adi_bin,percent

//parsimonious model
stcox age female post_htn hxsmk i.race_howell

**#AIC
//outcome: CV hospitalization among ever-hospitalized
//predictor: time varying post-donation diagnosis 
stcox post_htn age female hxsmk i.race_howell egfr_pre adi_bin open pre_hx_htn bmi income not_college_bin 
estimates store A

stcox post_htn age female hxsmk i.race_howell egfr_pre adi_bin
estimates store B

stcox post_htn age female hxsmk i.race_howell
estimates store C

stcox post_htn age female pre_hx_htn bmi hxsmk egfr_pre i.race_howell adi_bin
estimates store D

est stat A B C D // model A is the lowest AIC



**# Cox Proportional Hazard Model (predonation)
//fit cox model
stcox age female pre_hx_htn bmi hxsmk egfr_pre i.race_howell adi_bin post_htn

coefplot, drop(_cons) eform ///
title("Cox Regression (Post-donation HTN/DM)" , size(large) margin(tiny) color(black)) ///
subtitle("Cardiovascular vs Non-cardiovascular Related Hospitalization") ///
xline(1, lwidth(thin) lpattern(dash) lcolor(red%70)) ///
xscale(log) ///
xlab(0.5 "0.5" 1.0 "1.0" 1.5 "1.5" 2 "2.0" 3 "3.0" 4 "4.0", labsize(small)) ///
xtitle("Hazard Ratios and 95% Confidence Intervals" , margin(medsmall)) ///
ylab(1 "Age" ///
2  "Female" ///
3 "Pre-donation Hypertension History" ///
4 "BMI" ///
5 "Ever Smoke" ///
6 "eGFR" ///
7 "Hispanic, Any Race" ///
8 "Non-Hispanic Black" ///
9 "Non-Hispanic Asian/Indigenous/Other" ///
10 "High Area Deprivation Index (>=38%)" ///
11 "Post-donation HTN/DM" ///
, labsize(2.3)) ///
mlabel format(%9.2f) mlabposition(12) mlabgap(*.5) mlabsize(2) ///
legend(off) ciopts(lwidth(*1 *5)) ///
levels(95) msym(s) mfcolor(white) ///
note("OR per 10 year increase in age at donation" ///
"OR per 5 kg/m2 increase in pre-donation body mass index (BMI)" ////
"OR per 10 ml/min/1.73 m2 increase in eGFR (CKD-EPI 2021)" ///
"Area Deprivation Index (ADI) data from the Neighborhood Atlas by the University of Wisconsin, matched by census block group" ///
"Higher ADI is associated with more disadvantage" ///
,span size(vsmall)) ///
plotregion(margin(zero)) ///
graphregion(color(white))
graph export "cox_cv_hosp_post_htn.png", as(png) width(1200) replace
graph export "cox_cv_hosp_post_htn.tiff", as(tif) width(3000) replace



