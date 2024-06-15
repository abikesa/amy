capture log close _all
capture cmdlog close
clear all 

cd "S:\whole\01_Hospitalization"
log using "log_11_tv_cox_dm_htn_${cdat}.log",  replace

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

order wholeid s_date  firsthosp_yr hosp_bin  new_post_htn_yr new_post_dm_yr

//numbers
count
tab hosp_bin

gen htn_prehosp=new_post_htn_yr<firsthosp_yr & !mi(firsthosp_yr)
gen dm_prehosp=new_post_dm_yr<firsthosp_yr & !mi(firsthosp_yr)
egen htndm_prehosp=rowmax(htn_prehosp dm_prehosp) 

tab hosp_bin htn_prehosp,r m
tab hosp_bin dm_prehosp,r m
tab hosp_bin htndm_prehosp, r m

//first of Post-donation HTN or DM (using new_post_htn_yr variable)
gen new_post_htn_yr_old = new_post_htn_yr,after(new_post_htn_yr)
replace new_post_htn_yr = min(new_post_htn_yr,new_post_dm_yr)

//making new_post_htn var a combo of dm + HTN
replace new_post_htn = 1 if new_post_htn==1 | new_post_dm==1

//generate duplicate row for those with a post donation htn date
//ppl with 0 have 1 row of data 
//ppl with new_post_htn_yr>0 followed from 0 -> htn then htn -> survey/hosp
	gen needs_expanding = 1 if new_post_htn_yr>0 ///
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
	
	save tv_dm_htn, replace
	
	//bys wholeid: replace end=end+0.1 if end[_n-1]==end+0.1
	stset end , origin(start) id(wholeid) fail(outcome)
	lab var post_htn "Post-donation HTN/DM"
	
//full model
	stcox post_htn age female bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin insurance_pre adi_bin
	
//missingness
	missings report post_htn age female pre_hx_htn bmi sbp dbp hxsmk egfr_pre race_howell income not_college_bin insurance_pre adi_bin,percent

//parsimonious model
stcox post_htn age female hxsmk i.race_howell



//full model
stcox post_htn age female bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin insurance_pre adi_bin

coefplot, drop(_cons) eform ///
xline(1, lwidth(thin) lpattern(dash) lcolor(red%70)) ///
xlab(0.5 "0.5"  1.0 "1.0" 1.5 "1.5" 2 "2.0" 2.5 "2.5" 3 "3.0", labsize(small)) ///
xscale(log) ///
xtitle("Hazard Ratios and 95% Confidence Intervals" , margin(medsmall)) ///
ylab(1 "Post-donation DM or HTN" ///
2 "Age" ///
3 "Female" ///
4 "BMI" ///
5 "Systolic Blood Pressure" ///
6 "Diastolic Blood Pressure" ///
7 "Ever Smoke" ///
8 "eGFR" ///
9 "Hispanic, Any Race" ///
10 "Non-Hispanic Black" ///
11 "Non-Hispanic Asian/Indigenous/Other" ///
12 "Household Income" ///
13 "Not 4-year college graduate" ///
14 "Insurance" ///
15 "High Area Deprivation Index (>=38%)", labsize(2.3)) ///
mlabel format(%9.2f) mlabposition(12) mlabgap(*.5) mlabsize(2) ///
legend(off) ciopts(lwidth(*1 *5)) ///
levels(95) msym(s) mfcolor(white) ///
note("OR per 10 year increase in age at donation" ///
"OR per 5 kg/m2 increase in pre-donation body mass index (BMI)" ////
"OR per 10 mmHg increase in pre-donation systolic and diastolic blood pressure" ////
"OR per 10 ml/min/1.73 m2 increase in eGFR (CKD-EPI 2021)" ///
"OR per $10,000 increase in household income, matched by census tract GEOID using US Census Bureau data" ///
"Area Deprivation Index (ADI) data from the Neighborhood Atlas by the University of Wisconsin, matched by census block group" ///
"Higher ADI is associated with more disadvantage" ///
,span size(vsmall)) ///
plotregion(margin(zero)) ///
graphregion(color(white))
qui: graph export "cox_hosp_post.png", as(png) width(1200) replace
qui: graph export "cox_hosp_post.tiff", as(tif) width(3000) replace
end
end


//parsimonious
stcox post_htn age female hxsmk i.race_howell

coefplot, drop(_cons) eform ///
title("Cox Proportional Hazard Model" , size(large) margin(tiny) color(black)) ///
subtitle("Time-varying Post-donation Diabetes or Hypertension") ///
xline(1, lwidth(thin) lpattern(dash) lcolor(red%70)) ///
xlab(0.5 "0.5" 1.0 "1.0" 1.5 "1.5" 2 "2.0" 2.5 "2.5" 3 "3.0", labsize(small)) ///
xscale(range(0 3)) ///
xtitle("Hazard Ratios and 95% Confidence Intervals" , margin(medsmall)) ///
ylab(1 "Post-donation DM or HTN" ///
2 "Age" ///
3 "Female" ///
4 "Ever Smoke" ///
5 "Hispanic, Any Race" ///
6 "Non-Hispanic Black" ///
7 "Non-Hispanic Asian/Indigenous/Other" , labsize(2.3)) ///
mlabel format(%9.2f) mlabposition(12) mlabgap(*.5) mlabsize(2) ///
legend(off) ciopts(lwidth(*1 *5)) ///
levels(95) msym(s) mfcolor(white) ///
note("OR per 10 year increase in age at donation" ///
"OR per 5 kg/m2 increase in pre-donation body mass index (BMI)" ////
"OR per 10 ml/min/1.73 m2 increase in eGFR (CKD-EPI 2021)" ///
,span size(vsmall)) ///
plotregion(margin(zero)) ///
graphregion(color(white))
qui: graph export "cox_hosp_post_parsimonious.png", as(png) width(1200) replace
qui: graph export "cox_hosp_post_parsimonious.tiff", as(tif) width(3000) replace


**# Kaplan with tv
//plot the kaplan meier failure
sts graph, failure risktable ///
by(post_htn) ///
tmax(20) ///
title("Cumulative Incidence Of First Hospitalization" "Since Live Kidney Donation", color(black)) ///
subtitle("By Time Varying Post-donation Diabetes or Hypertension") ///
xtitle("Years Post-donation", size(med) margin(medsmall) color(black)) ///
ytitle("Proportion of LKDs Hospitalized (%)") ///
ylab(0 "0" 0.1 "10" 0.2 "20" 0.3 "30" 0.4 "40" 0.5 "50" 0.6 "60" 0.7 "70" 0.8 "80" , angle(0)) ///
xlab(1 "1" 3 "3" 5 "5" 10 "10" 15 "15" 20 "20") ///
note("Patients that reported hospitalization, but not year of hospitalization, were excluded (n=72)" ///
"Patients were censored at their year of first hospitalization or survey date", span  size(vsmall)) ///
legend(label(1 "Never Post-donation DM/HTN") label(2 "With Post-donation DM/HTN")) ///
plotregion(margin(zero)) ///
graphregion(color(white))
qui: graph export "km_survival_posthtndm.png", as(png) width(1200) replace
qui: graph export "km_survival_posthtndm.tiff", as(tif) width(3000)replace

//cumulative incidence at each specified year
sts list, failure at(1 3 5 10 15 20) 


**#AIC
//outcome: all-hospitalization
//predictor: time varying post-donation diagnosis of HTN OR DM 
stcox post_htn age female bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin insurance_pre adi_bin
estimates store A

stcox post_htn age female hxsmk i.race_howell egfr_pre adi_bin
estimates store B

stcox post_htn age female hxsmk i.race_howell
estimates store C

est stat A B C // model A is the lowest AIC



**# compare parsimonious vs full model demographic
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

gen newpost= new_post_htn==1 | new_post_dm==1


gen fullonly=.
replace fullonly=0 if !mi(newpost) & !mi(age) & !mi(female) & !mi(hxsmk) & !mi(race_howell)
replace fullonly=1 if fullonly==0 & !mi(bmi) & !mi(sbp) & !mi(dbp) & !mi(egfr_pre) & !mi(income) & !mi(not_college_bin) & !mi(insurance_pre) & !mi(adi_bin)
lab var fullonly "Missing in Full Model, but Present in Parsimonious"
lab def fullonly 0 "Parsiminious+Full" 1 "Only Full"

table1, ///
by(fullonly) ///
vars(newpost bin \ tx_age conts \ female bin \ race_howell cat \ hxsmk bin \ last_pretx_bmi conts \ last_pretx_sbp conts \ last_pretx_dbp conts \ ckdepi_pre conts \ not_college_bin bin \ insurance_pre bin \ adi_bin bin \ s_date conts \ hosp_bin bin) ///
onecol cformat(%3.0f) format(%3.0f) cmissing ///
saving(fullvspars_${cdat}, replace)