capture log close _all
capture cmdlog close
clear all 

cd "S:\whole\01_Hospitalization"
global cdat: di %tdCCYYNNDD date(c(current_date),"DMY") 
log using "log_07_regression_${cdat}.log",  replace

**# Regression
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

**# Final Model (model C- ATC and manuscript)
logistic hosp_bin age female open pre_hx_htn bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin insurance_pre adi_bin 
//lroc
sum hosp_bin hosp_bin 

coefplot, drop(_cons) eform ///
title("Figure 1: Logistic Regression Comparing" "Hospitalization Status Among Live Kidney Donors" ///
, size(med) margin(medsmall) color(black)) ///
xline(1, lwidth(thin) lpattern(dash) lcolor(red%50)) ///
xscale(r(0 4)) ///
xlab( 0.25 ".25" 0.5 ".5" 1 "1" 2 "2" 3 "3" 4 "4" , labsize(small)) ///
xtitle("Odds Ratios and 95% Confidence Intervals", margin(medsmall)) ///
ylab(1 "Age at Donation" ///
	2  "Female" ///
	3 "Open procedure" ///
	4 "Hypertension History" ///
	5 "BMI" ///
	6 "Systolic Blood Pressure" ///
	7 "Diastolic Blood Pressure" ///
	8 "Ever Smoke" ///
	9 "eGFR" ///
	10 "Hispanic, Any Race" ///
	11 "Non-Hispanic Black" ///
	12 "Non-Hispanic Asian/Indigenous/Other" ///
	13 "Household Income" ///
	14 "Not 4-year college graduate" ///
	15 "Insurance" ///
	16 "High Area Deprivation Index (>=38%)" ///
	, labsize(2.3)) ///
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
graph export "hosp_bin_logistic_baseline.png", as(png) width(1200) replace
graph export "hosp_bin_logistic_baseline.tiff", as(tif) width(3000) replace

**# Model C --post dm cv (*ATC and manuscript)
logistic hosp_bin age female open pre_hx_htn bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin insurance_pre adi_bin new_post_dm post_hx_cv


coefplot, drop(_cons) eform ///
title("Figure 2: Logistic Regression Comparing" "Hospitalization Status Among Live Kidney Donors" , size(med) margin(tiny) color(black))  ///
subtitle("Looking at Post-donation Diabetes and Cardiovascular Disease", size(small) margin(tiny)) ///
xline(1, lwidth(thin) lpattern(dash) lcolor(red%50)) ///
xscale(r(0 4)) ///
xlab( 0.25 ".25" 0.5 ".5" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6" 7 "7", labsize(small)) ///
xtitle("Odds Ratios and 95% Confidence Intervals", margin(medsmall)) ///
ylab(1 "Age at Donation" ///
	2  "Female" ///
	3 "Open procedure" ///
	4 "Hypertension History" ///
	5 "BMI" ///
	6 "Systolic Blood Pressure" ///
	7 "Diastolic Blood Pressure" ///
	8 "Ever Smoke" ///
	9 "eGFR" ///
	10 "Hispanic, Any Race" ///
	11 "Non-Hispanic Black" ///
	12 "Non-Hispanic Asian/Indigenous/Other" ///
	13 "Household Income" ///
	14 "Not 4-year college graduate" ///
	15 "Insurance" ///
	16 "High Area Deprivation Index (>=38%)" ///
	17 "Post-donation Diabetes" ///
	18 "Post-donation Cardiovascular Disease" ///
	, labsize(2.3)) ///
mlabel format(%9.2f) mlabposition(12) mlabgap(*.5) mlabsize(2) ///
legend(off) ciopts(lwidth(*1 *5)) ///
levels(95) msym(s) mfcolor(white) ///
plotregion(margin(zero)) ///
graphregion(color(white))

graph export "hosp_bin_logistic_post_dm_cv.png", as(png) width(1200) replace
graph export "hosp_bin_logistic_post_dm_cv.tiff", as(tif) width(3000) replace

//
end

*MODEL X
*saturated (adi_bin: binary at median)
logistic hosp_bin age female bmi pre_hx_htn sbp dbp hxsmk egfr_pre i.race_howell income i.edu_whole insurance_pre adi_bin
estimates store X

*MODEL Y
*saturated (adi_cat: categorical in quartiles)
logistic hosp_bin age female bmi pre_hx_htn sbp dbp hxsmk egfr_pre i.race_howell income i.edu_whole insurance_pre i.adi_cat
estimates store Y

lrtest X Y, stat // Model Y p=0.03; adi_cat with lower AIC


**# Akaike
*MODEL A
**original
logistic hosp_bin age female bmi pre_hx_htn sbp dbp hxsmk egfr_pre i.race_howell income i.edu_whole insurance_pre
estimates store A

*MODEL B
*saturated (adi_cat: categorical in quartiles)
logistic hosp_bin age female bmi pre_hx_htn sbp dbp hxsmk egfr_pre i.race_howell income i.edu_whole insurance_pre i.adi_bin
estimates store B

*MODEL C
*saturated (adi_cat: categorical in quartiles)
logistic hosp_bin age female bmi pre_hx_htn sbp dbp hxsmk egfr_pre i.race_howell income i.edu_whole insurance_pre i.adi_cat
estimates store C

est stat A B C // model C is the lowest AIC

*MODEL D 
*saturated (adi_cat), No race or ethnicity
*age, income, bmi, and egfr as continuous
logistic hosp_bin age female bmi pre_hx_htn sbp dbp hxsmk egfr_pre income i.edu_whole insurance_pre i.adi_cat
estimates store D

*MODEL E
*saturated (adi_cat), No race or ethnicity, education, insurance
*age, income, bmi, and egfr as continuous
logistic hosp_bin age female bmi pre_hx_htn sbp dbp hxsmk egfr_pre i.adi_cat
estimates store E

*MODEL F
*saturated (adi_cat), No education or insurance
*age, income, bmi, and egfr as continuous
logistic hosp_bin age female bmi pre_hx_htn sbp dbp hxsmk egfr_pre i.race_howell i.adi_cat
estimates store F

est stat A B C D E F //lowest AIC is model C

//logistic regression model 20221021 (Mary Grace)

**# ORIGINAL
logistic hosp_bin age female i.race hispanic bmi income i.edu_whole hxsmk pre_hx_htn pre_hx_dm egfr_pre 
predict hosp_bin_pred
sum hosp_bin_pred
drop hosp_bin_pred

coefplot, drop(_cons) eform ///
title("Comparing Hospitalized to Never Hospitalized" "Among Live Kidney Donors", size(med) margin(medsmall) color(black)) ///
xline(1, lwidth(thin) lpattern(dash) lcolor(red%70)) ///
xscale(log) ///
xlab(0.5 "0.5" 1.0 "1.0" 1.5 "1.5" 2 "2.0" 4 "4.0" 6 "6.0", labsize(small)) ///
xtitle("Odds Ratios and 95% Confidence Intervals" , margin(medsmall)) ///
ylab(1 "Age" ///
2  "Female" ///
3 "Black/African American" ///
4 "Asian/Pacific Islander" ///
5 "American Indian/Alaska Native" ///
6 "Other Race" ///
7 "Hispanic" ///
8 "BMI" ///
9 "Household Income" ///
10 "High school" ///
11 "K-8" ///
12 "Ever Smoke" ///
13 "Hypertension History" ///
14 "Pre-donation eGFR", labsize(small)) ///
mlabel format(%9.2f) mlabposition(12) mlabsize(small) ///
legend(off) ciopts(lwidth(*1 *5)) ///
levels(95) msym(s) mfcolor(white) ///
note("OR per 10 year increase in age at donation" ///
"OR per 5 kg/m2 increase in pre-donation body mass index" ////
"OR per 10 ml/min/1.73 m2 increase in pre-donation eGFR (CKD-EPI 2021)" ///
"OR per $10,000 increase in household income, matched by census tract GEOID using US Census Bureau data" ///
"Smoking, cardiovascular, and diabetes history are pre or post donation status" ///
,span size(vsmall)) ///
graphregion(color(white))
graph export "${FIG}hosp_bin_logistic.png", as(png) replace





**# Final Model (C- Bio only)
logistic hosp_bin age female pre_hx_htn bmi sbp dbp hxsmk egfr_pre 
predict hosp_bin_pred
sum hosp_bin_pred
drop hosp_bin_pred

coefplot, drop(_cons) eform ///
title("Comparing Hospitalized to Never Hospitalized" "Among Live Kidney Donors", size(med) margin(medsmall) color(black)) ///
xline(1, lwidth(thin) lpattern(dash) lcolor(red%50)) ///
xscale(r(0 4)) ///
xlab( 0.25 "0.25" 0.5 "0.5" 1 "1" 2 "2" 3 "3" 4 "4" , labsize(small)) ///
xtitle("Odds Ratios and 95% Confidence Intervals", margin(medsmall)) ///
ylab(1 "Age at Donation" ///
	2  "Female" ///
	3 "Hypertension History" ///
	4 "BMI" ///
	5 "Systolic Blood Pressure" ///
	6 "Diastolic Blood Pressure" /// 
	7 "Ever Smoke" ///
	8 "eGFR", labsize(small)) ///
mlabel format(%9.2f) mlabposition(12) mlabsize(2) ///
legend(off) ciopts(lwidth(*1 *5)) ///
levels(95) msym(s) mfcolor(white) ///
note("OR per 10 year increase in age at donation" ///
"OR per 5 kg/m2 increase in pre-donation body mass index (BMI)" ////
"OR per 10 mmHg increase in pre-donation systolic and diastolic blood pressure" ////
"OR per 10 ml/min/1.73 m2 increase in eGFR (CKD-EPI 2021)" ///
,span size(vsmall)) ///
plotregion(margin(zero)) ///
graphregion(color(white))
graph export "hosp_bin_logistic_model C_bio.emf", as(emf) replace

**# Model C --with mediators
tab new_post_htn
tab new_post_dm
tab post_hx_cv //INCLUDES HTN, chf, cad, athero, hyperlip, pvd, stroke, mi

logistic hosp_bin age female pre_hx_htn bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin insurance_pre adi_bin new_post_htn 

logistic hosp_bin age female pre_hx_htn bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin insurance_pre adi_bin new_post_dm

logistic hosp_bin age female pre_hx_htn bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin insurance_pre adi_bin new_post_htn new_post_dm

logistic hosp_bin age female pre_hx_htn bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin insurance_pre adi_bin post_hx_cv

logistic hosp_bin age female pre_hx_htn bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin insurance_pre adi_bin new_post_dm post_hx_cv
vif ,uncentered 
tab post_hx_cv new_post_dm
tab new_post_htn new_post_dm

tab new_post_dm new_post_htn,sum(hosp_bin) mean


logistic hosp_bin age pre_hx_htn bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin insurance_pre adi_bin post_hx_preg if female==1






**# Race and ADI interaction
logistic hosp_bin i.adi_bin##i.race_howell age female bmi pre_hx_htn sbp dbp hxsmk egfr_pre income i.edu_whole insurance_pre 

gen nonwhite=race_howell>0
replace nonwhite=. if mi(race_howell)

logistic hosp_bin i.adi_bin##i.nonwhite age female bmi pre_hx_htn sbp dbp hxsmk egfr_pre income i.edu_whole insurance_pre 
end
logistic hosp_bin c.adi_natrank##i.race_howell age female bmi pre_hx_htn sbp dbp hxsmk egfr_pre income i.edu_whole insurance_pre 

logistic hosp_bin c.adi_natrank##white age female bmi pre_hx_htn sbp dbp hxsmk egfr_pre income i.edu_whole insurance_pre 

logistic hosp_bin c.adi_natrank##black age female bmi pre_hx_htn sbp dbp hxsmk egfr_pre income i.edu_whole insurance_pre 



//if statistically signif report stratified
logistic hosp_bin i.adi_bin##black
bys black: logistic hosp_bin i.adi_bin	

		
logistic hosp_bin c.adi_natrank##hispanic age female bmi pre_hx_htn sbp dbp hxsmk egfr_pre income i.edu_whole insurance_pre 

end
**# ADI subgroup
clear all
use hosp_final, clear
	gen age65=tx_age>=65 if !mi(tx_age)
		lab var age65 "Age at Donation >=65"
	gen egfr90=ckdepi_pre<90 if !mi(ckdepi_pre)
		lab var egfr90 "PRE Donation eGFR <90"
	gen sbp130=last_pretx_sbp>=130 if !mi(last_pretx_sbp)
		lab var sbp130 "PRE-Don sBP >=130"
	gen dbp80=last_pretx_dbp>=80 if !mi(last_pretx_dbp)
		lab var dbp80 "PRE-Don dBP >=80"
	gen income=hh_income<70391 if !mi(hh_income)
		lab var income "Household Income <70391 (median)"
	
	gen obese=last_pretx_bmi>=30 if !mi(last_pretx_bmi)
		lab var obese "BMI >=30"

	
foreach v in age65 egfr90 sbp130 dbp80 obese adi_cat adi_bin {
	lab val `v' `v'
}

**test logistic regression using different types of ADI (cont, binary, categ)
table1, by(hosp_bin) vars(adi_natrank conts)
logistic hosp_bin adi_natrank
logistic hosp_bin age65 female i.race hispanic obese i.edu_whole income adi_natrank hxsmk hx_cv hx_dm egfr90

tab adi_bin hosp_bin, chi
logistic hosp_bin adi_bin
logistic hosp_bin age65 female i.race hispanic obese i.edu_whole income adi_bin hxsmk hx_cv hx_dm egfr90 

tab adi_cat hosp_bin, chi
logistic hosp_bin i.adi_cat
logistic hosp_bin age65 female i.race hispanic obese i.edu_whole income i.adi_cat hxsmk hx_cv hx_dm egfr90 


*#logistic regression model 20230310
*comparing likelihood ratios to see if race makes a difference 
logistic hosp_bin adi_bin age65 female obese hxsmk hx_cv hx_dm egfr90 if !mi(race)
estimates store A
logistic hosp_bin adi_bin age65 female obese hxsmk hx_cv hx_dm egfr90 i.race
estimates store B
lrtest A B, stats //p=0.48

logistic hosp_bin i.adi_cat age65 female obese hxsmk hx_cv hx_dm egfr90 if !mi(race)
estimates store A
logistic hosp_bin i.adi_cat age65 female obese hxsmk hx_cv hx_dm egfr90 i.race
estimates store B
lrtest A B, stats //p=0.50


*comparing LLR for hispanic
logistic hosp_bin adi_bin age65 female obese hxsmk hx_cv hx_dm egfr90 if !mi(hispanic)
estimates store A
logistic hosp_bin adi_bin age65 female obese hxsmk hx_cv hx_dm egfr90 i.hispanic
estimates store B
lrtest A B, stats //p=0.76

*comparing LLR for education
logistic hosp_bin adi_bin age65 female obese hxsmk hx_cv hx_dm egfr90 if !mi(edu_whole)
estimates store A
logistic hosp_bin adi_bin age65 female obese hxsmk hx_cv hx_dm egfr90 i.edu_whole
estimates store B
lrtest A B, stats //p=0.77

*comparing LLR for household income
logistic hosp_bin adi_bin age65 female obese hxsmk hx_cv hx_dm egfr90 if !mi(income)
estimates store A
logistic hosp_bin adi_bin age65 female obese hxsmk hx_cv hx_dm egfr90 income
estimates store B
lrtest A B, stats //p=0.10

**new adi binary
logistic hosp_bin age65 female obese hxsmk hx_cv hx_dm egfr90 adi_bin

coefplot, drop(_cons) eform ///
xline(1, lwidth(thin) lpattern(dash)) ///
xscale(log) ///
xlab(1.0 "1.0" 1.5 "1.5" 2 "2.0" 3 "3.0" 4 "4.0", labsize(small)) ///
xtitle("Odds Ratios and 95% Confidence Intervals" " " "Comparing Hospitalized to Never Hospitalized" "Live Kidney Donors By Demographic and Health Characteristics" , margin(medsmall)) ///
ylab(1 "Age >=65 at Donation" 2  "Female" 3 "BMI >=30 Pre-Donation" 4 "Ever Smoke" 5 "Cardiovascular History" 6 "Diabetes History" 7 "eGFR <90 Pre-Donation" 8 "Area Deprivation Index", labsize(small)) ///
mlabel format(%9.2f) mlabposition(12) mlabsize(small) ///
legend(off) ciopts(lwidth(*1 *5)) ///
levels(95) msym(s) mfcolor(white) ///
note("Area Deprivation Index is matched by US Census Bureau GEOID and the Neighborhood Atlas by the University of Wisconsin " ///
"Smoking, cardiovascular, and diabetes history is pre or post donation status" ///
,span size(vsmall)) ///
graphregion(color(white))
graph export "S:\whole\fig\hosp_bin_logistic_adi_bin_new.png", as(png) replace

**old adi binary
logistic hosp_bin age65 female i.race hispanic obese i.edu_whole income hxsmk hx_cv hx_dm egfr90 adi_bin


coefplot, drop(_cons) eform ///
xline(1, lwidth(thin) lpattern(dash)) ///
xscale(log) ///
xlab(0.5 "0.5" 1.0 "1.0" 1.5 "1.5" 2 "2.0" 4 "4.0" 6 "6.0", labsize(small)) ///
xtitle("Odds Ratios and 95% Confidence Intervals" " " "Comparing Hospitalized to Never Hospitalized" "Live Kidney Donors By Demographic and Health Characteristics" , margin(medsmall)) ///
ylab(1 "Age >=65" 2  "Female" 3 "Black/African American" 4 "Asian/Pacific Islander" 5 "American Indian/Alaska Native" 6 "Other Race" 7 "Hispanic" 8 "Predonation BMI >=30" 9 "High school" 10 "K-8" 11 "Household Income <$70,391" 12 "Ever Smoke" 13 "Cardiovascular History" 14 "Diabetes History" 15 "Predonation eGFR <90" 16 "Area Deprivation Index (binary)", labsize(small)) ///
mlabel format(%9.2f) mlabposition(12) mlabsize(small) ///
legend(off) ciopts(lwidth(*1 *5)) ///
levels(95) msym(s) mfcolor(white) ///
note("Area Deprivation Index is matched by US Census Bureau GEOID and the Neighborhood Atlas by the University of Wisconsin " ///
"Smoking, cardiovascular, and diabetes history is pre or post donation status" ///
,span size(vsmall)) ///
graphregion(color(white))
graph export "S:\whole\fig\hosp_bin_logistic_adi_bin_old.png", as(png) replace


**new adi cat
logistic hosp_bin age65 female obese hxsmk hx_cv hx_dm egfr90 i.adi_cat

coefplot, drop(_cons) eform ///
xline(1, lwidth(thin) lpattern(dash)) ///
xscale(log) ///
xlab(1.0 "1.0" 1.5 "1.5" 2 "2.0" 3 "3.0" 4 "4.0", labsize(small)) ///
xtitle("Odds Ratios and 95% Confidence Intervals" " " "Comparing Hospitalized to Never Hospitalized" "Live Kidney Donors By Demographic and Health Characteristics" , margin(medsmall)) ///
ylab(1 "Age >=65 at Donation" 2  "Female" 3 "BMI >=30 Pre-Donation" 4 "Ever Smoke" 5 "Cardiovascular History" 6 "Diabetes History" 7 "eGFR <90 Pre-Donation" 8 "ADI Second Quartile (19%-37%)" 9 "ADI Third Quartile (38%-59%)" 10 "ADI Fourth Quartile (>59%)", labsize(small)) ///
mlabel format(%9.2f) mlabposition(12) mlabsize(small) ///
legend(off) ciopts(lwidth(*1 *5)) ///
levels(95) msym(s) mfcolor(white) ///
note("Area Deprivation Index is matched by US Census Bureau GEOID and the Neighborhood Atlas by the University of Wisconsin " ///
"Smoking, cardiovascular, and diabetes history is pre or post donation status" ///
,span size(vsmall)) ///
graphregion(color(white))
graph export "S:\whole\fig\hosp_bin_logistic_adi_cat_new.png", as(png) replace

**old adi cat
logistic hosp_bin age65 female i.race hispanic obese i.edu_whole income hxsmk hx_cv hx_dm egfr90 i.adi_cat


coefplot, drop(_cons) eform ///
xline(1, lwidth(thin) lpattern(dash)) ///
xscale(log) ///
xlab(0.5 "0.5" 1.0 "1.0" 1.5 "1.5" 2 "2.0" 4 "4.0" 6 "6.0", labsize(small)) ///
xtitle("Odds Ratios and 95% Confidence Intervals" " " "Comparing Hospitalized to Never Hospitalized" "Live Kidney Donors By Demographic and Health Characteristics" , margin(medsmall)) ///
ylab(1 "Age >=65" 2  "Female" 3 "Black/African American" 4 "Asian/Pacific Islander" 5 "American Indian/Alaska Native" 6 "Other Race" 7 "Hispanic" 8 "Predonation BMI >=30" 9 "High school" 10 "K-8" 11 "Household Income <$70,391" 12 "Ever Smoke" 13 "Cardiovascular History" 14 "Diabetes History" 15 "Predonation eGFR <90" 16 "ADI Second Quartile (19%-37%)" 17 "ADI Third Quartile (38%-59%)" 18 "ADI Fourth Quartile (>59%)", labsize(small)) ///
mlabel format(%9.2f) mlabposition(12) mlabsize(small) ///
legend(off) ciopts(lwidth(*1 *5)) ///
levels(95) msym(s) mfcolor(white) ///
note("Area Deprivation Index is matched by US Census Bureau GEOID and the Neighborhood Atlas by the University of Wisconsin " ///
"Smoking, cardiovascular, and diabetes history is pre or post donation status" ///
,span size(vsmall)) ///
graphregion(color(white))
graph export "S:\whole\fig\hosp_bin_logistic_adi_cat_old.png", as(png) replace


end

table1, ///
vars(tx_age conts \ last_pretx_sbp conts \ last_pretx_dbp conts \ last_pretx_bmi conts \ ckdepi conts \ hh_income conts \ female bin \ ///
hxsmk bin \ nonwhite cat \ college_bin bin \ tx_center cat \ ///
hosp_bin bin \ firsthospyr conts \ pcp_5yr bin \ ///
hi_barr bin \ li_barr bin \ ///
pre_hx_ckd bin \ pre_hx_htn bin \ pre_hx_dm bin \ pre_hx_cancer bin \ ///
don_bp_preop_syst conts \ don_bp_preop_diast conts \ don_hist_hyperten cat \ don_ki_creat_preop conts \ don_ki_creat_dischrg conts \ ///
hx_ckd bin \ hx_cv bin \ hx_dm bin \ hx_cancer bin \ hx_heme bin \ hx_lung bin \ hx_thy bin \ hx_ckd_yr conts \ hx_htn_yr conts \ hx_dm_yr conts \ hx_cancer_yr conts ///
hosp_surg_bin bin \ hosp_uro_bin bin \ hosp_cv_bin bin \ hosp_ob_hemodynamics_bin bin \ hosp_symp_cv_bin bin \  hosp_adhesion_bin bin \ hosp_postop_comp_bin bin \ hosp_fall_bin bin ) ///
onecol cformat(%3.0f) format(%3.0f) cmissing ///
saving(${OUT}hosp_all_${cdat}, replace)


table1 if hosp_bin==1, ///
vars(tx_age conts \ last_pretx_sbp conts \ last_pretx_dbp conts \ last_pretx_bmi conts \ ckdepi conts \ hh_income conts \ female bin \ ///
hxsmk bin \ race cat \ white bin \ black bin \ hispanic bin \ college_bin bin \ tx_center cat \ ///
 firsthospyr conts \ pcp_5yr bin \ ///
hi_barr bin \ li_barr bin \ ///
hosp_surg_bin bin \ hosp_uro_bin bin \ hosp_cv_bin bin \ hosp_ob_hemodynamics_bin bin \ hosp_symp_cv_bin bin \  hosp_adhesion_bin bin \ hosp_postop_comp_bin bin \ hosp_fall_bin bin ) ///
onecol cformat(%3.0f) format(%3.0f) cmissing ///
saving(${OUT}hosp_onlyhosp_${cdat}, replace)

sum firsthospyr, d




histogram hh_income, bin(13) addlabopts(mlabformat(%3.1f)) percent ///
title("Median household income" "matched by zipcode and 2018 Census") ///
xtitle("USD ($10k)") ///
xlabel(30000 "30" 50000 "50" 75000 "75" 100000 "100" 125000 "125" 150000 "150" 200000 "200" 250000 "250" ) ///
ylab(#5, angle(0)) ///
fcolor(ebblue%50) lcolor(ebblue%90) ///
mlabformat(%3.1f) ///
bgcolor(white) ///
plotregion(margin(small) fcolor(none) lcolor(none)) ///
graphregion(color(white) margin(medlarge)) 	
graph export ${FIG}histo_hosp_hh_income.png, width(1200) replace

histogram hh_income, by(hosp_bin, col(2)) bin(8) binrescale addlabopts(mlabformat(%3.1f)) percent ///
xtitle("USD ($10k)") ///
xlabel(30000 "30" 50000 "50" 75000 "75" 100000 "100" 125000 "125" 150000 "150" 200000 "200" 250000 "250" ) ///
ylabel(5 "5" 10 "10" 15 "15" 20 "20" 25 "25" 30 "30" 35 "35" 40 "40" 45 "45", angle(0)) ///
fcolor(ebblue%50) lcolor(ebblue%90) ///
legend(off) ///
bgcolor(white) ///
plotregion(margin(small) fcolor(none) lcolor(none)) ///
graphregion(color(white) margin(medlarge)) 	
graph export ${FIG}histo_hosp_hh_income_bin.png, width(1200) replace




table1 if hosp_bin==1 , ///
vars(tx_age conts \ last_pretx_sbp conts \ last_pretx_dbp conts \ last_pretx_bmi conts \ ckdepi conts \ hh_income conts \ gender cat \ ///
hxsmk cat \ race cat \ hisp cat \ edu cat \ tx_center cat \ ///
hosp_surg_bin bin \ hosp_uro_bin bin \ hosp_cv_bin bin \ hosp_ob_hemodynamics_bin bin \ hosp_symp_cv_bin bin \  hosp_adhesion_bin bin \ hosp_postop_comp_bin bin \ hosp_fall_bin bin ) /// hosp_symp_uro_bin none
onecol cformat(%3.1f) format(%3.1f) cmissing ///
saving(${OUT}hosp_icd10_${cdat}, replace)

table1 if hosp_bin==1 , ///
by(hosp_surg_bin) ///
vars(gender cat \ race cat \ hisp cat \ tx_center cat \ tx_age conts \ edu cat \ hh_income conts \ er_freq conts \ hosp_freq conts \ ///
last_pretx_sbp conts \ last_pretx_dbp conts \  last_pretx_glu conts \ ckdepi conts \ ///
hosp_uro_bin bin \ hosp_cv_bin bin \ hosp_ob_hemodynamics_bin bin \ hosp_symp_cv_bin bin \  hosp_adhesion_bin bin \ hosp_postop_comp_bin bin \ hosp_fall_bin bin ) ///
onecol cformat(%3.1f) format(%3.1f) cmissing ///
saving(${OUT}hosp_icd10_surg_${cdat}, replace)

table1 if hosp_bin==1 , ///
by(hosp_uro_bin) ///
vars(gender cat \ race cat \ hisp cat \ tx_center cat \ tx_age conts \ edu cat \ hh_income conts \ er_freq conts \ hosp_freq conts \ ///
last_pretx_sbp conts \ last_pretx_dbp conts \  last_pretx_glu conts \ ckdepi conts \ ///
hosp_surg_bin bin \ hosp_cv_bin bin \ hosp_ob_hemodynamics_bin bin \ hosp_symp_cv_bin bin \  hosp_adhesion_bin bin \ hosp_postop_comp_bin bin \ hosp_fall_bin bin ) ///
onecol cformat(%3.1f) format(%3.1f) cmissing ///
saving(${OUT}hosp_icd10_uro_${cdat}, replace)

table1 if hosp_bin==1 , ///
by(hosp_cv_bin) ///
vars(tx_age conts \ last_pretx_sbp conts \ last_pretx_dbp conts \ last_pretx_bmi conts \ ckdepi conts \ hh_income conts \ gender bin \ ///
hxsmk bin \ race cat \ hisp bin \ edu cat \ tx_center cat \ ///
hosp_surg_bin bin \ hosp_uro_bin bin \ hosp_ob_hemodynamics_bin bin \ hosp_symp_cv_bin bin \  hosp_adhesion_bin bin \ hosp_postop_comp_bin bin \ hosp_fall_bin bin ) ///
onecol cformat(%3.0f) format(%3.0f) cmissing ///
saving(${OUT}hosp_icd10_cv_${cdat}, replace)

/*
**# Hospitalization J Motter
clear all
use whole_hosp
keep wholeid tx_dt tx_yr gender hisp tx_center tx_age race unos_id
destring unos_id, gen(unos_int) force

replace unos_id = lower(unos_id)
gen unos_alph=regexm(lower(unos_id), "a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z") & !mi(unos_id)
replace unos_id = "" if unos_alph!=1
drop unos_alph

save "whole_srtr_hosp", replace 

//drop all text first


**# Hospitalization Tables
clear all
use hosp_icd10

table1 , ///
vars(gender cat \ race cat \ hisp cat \ tx_center cat \ tx_age conts \ edu cat \ hh_income conts \ ckdepi conts \ ///
hosp_uro conts \ hosp_cv conts \ hosp_neo conts \ hosp_ob_hemodynamics conts \ hosp_symp_uro conts \ hosp_symp_cv conts \ hosp_fall conts \ hosp_adhesion conts ) ///
onecol cformat(%3.1f) format(%3.1f) cmissing ///
saving(${OUT}hosp_icd10cat_all_${cdat}, replace)


table1 , ///
by(uro_bin) ///
vars(gender cat \ race cat \ hisp cat \ tx_center cat \ tx_age conts \ edu cat \ hh_income conts \ ckdepi conts ) ///
onecol cformat(%3.1f) format(%3.1f) cmissing ///
saving(${OUT}hosp_icd10cat_byuro_${cdat}, replace)

table1 , ///
by(cv_bin) ///
vars(gender cat \ race cat \ hisp cat \ tx_center cat \ tx_age conts \ edu cat \ hh_income conts \ ckdepi conts ) ///
onecol cformat(%3.1f) format(%3.1f) cmissing ///
saving(${OUT}hosp_icd10cat_bycv_${cdat}, replace)


**# ER Tables
clear all
use er_icd10
table1 , ///
vars(gender cat \ race cat \ hisp cat \ tx_center cat \ tx_age conts \ edu cat \ hh_income conts \ ckdepi conts \ ///
er_uro conts \ er_cv conts \ er_neo conts \ er_ob_hemodynamics conts \ er_symp_uro conts \ er_symp_cv conts \ er_fall conts \ er_adhesion conts  ) ///
onecol cformat(%3.1f) format(%3.1f) cmissing ///
saving(${OUT}er_icd10cat_all_${cdat}, replace)


table1 , ///
by(uro_bin) ///
vars(gender cat \ race cat \ hisp cat \ tx_center cat \ tx_age conts \ edu cat \ hh_income conts \ ckdepi conts ) ///
onecol cformat(%3.1f) format(%3.1f) cmissing ///
saving(${OUT}er_icd10cat_byuro_${cdat}, replace)

table1 , ///
by(cv_bin) ///
vars(gender cat \ race cat \ hisp cat \ tx_center cat \ tx_age conts \ edu cat \ hh_income conts \ ckdepi conts ) ///
onecol cformat(%3.1f) format(%3.1f) cmissing ///
saving(${OUT}er_icd10cat_bycv_${cdat}, replace)
*/
**# Hospitalization Indraneel csv to dta
clear all
import delimited using ${SD}r\hospcauses.csv, case(lower)

**rename variables
rename ldfuid wholeid 

encode redcap_event_name, gen(x)
replace x=0 if strpos(redcap_event_name, "data_import_arm_") 
replace x=1 if strpos(redcap_event_name, "survey_1_arm_")
replace x=2 if strpos(redcap_event_name, "followup_1_arm_")
replace x=3 if strpos(redcap_event_name, "followup_2_arm_")
replace x=4 if strpos(redcap_event_name, "followup_3_arm_")
replace x=5 if strpos(redcap_event_name, "followup_4_arm_")
rename x rdc_row
lab def rdc_row 0 "dataimport" 1 "s1" 2 "fu1" 3 "fu2" 4 "fu3" 5 "fu4" , replace
lab val rdc_row rdc_row

gen survey_dt = date(survey_date, "YMD")
rename hosp_or_er_date hosper_yr
format survey_dt %td

rename hosp_or_er_num hosper_freq
drop redcap_event_name data_source survey_date v1

gen mihosp = mi(s1_hospitalization)
gen surveyyear = year(s1_date)
gsort wholeid dob_year
bys wholeid: gen dob_yr = dob_year[1]
gen s1_age = year(s1_date) - dob_yr
***NOT DONE***



