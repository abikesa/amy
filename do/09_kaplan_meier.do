capture log close _all
capture cmdlog close
clear all 

cd "S:\whole\01_Hospitalization"
log using "log_09_kaplan_meier_${cdat}.log",  replace

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


//censor those who were hospitalized or up to their survey date
egen studytime = rowmin(firsthosp_yr s_date)
	unique wholeid if (hosp_bin==1 & mi(firsthosp_yr)) | (mi(s_date) & mi(firsthosp_yr))
	drop if hosp_bin==1 & mi(firsthosp_yr) //n=69/2251
	drop if mi(studytime) //n=1
	
//replace those with years=0 to 0.1 to be included in the model
replace studytime=0.1 if studytime==0 //n=41

//setup and declare the data to be failure-time data
stset studytime, failure(hosp_bin==1) 

**# Kaplan Meier
//plot the kaplan meier failure
sts graph, failure risktable ///
tmax(20) ///
title("Cumulative Incidence Of First Hospitalization" "Since Live Kidney Donation", color(black)) ///
xtitle("Years Post-donation", size(med) margin(medsmall) color(black)) ///
ytitle("Proportion of LKDs Hospitalized (%)") ///
ylab(0 "0" 0.1 "10" 0.2 "20" 0.3 "30" 0.4 "40" 0.5 "50" 0.6 "60" , angle(0)) ///
xlab(1 "1" 3 "3" 5 "5" 10 "10" 15 "15" 20 "20") ///
note("Patients that reported hospitalization, but not year of hospitalization, were excluded (n=72)" ///
"Patients were censored at their survey date", span  size(vsmall)) ///
plotregion(margin(zero)) ///
graphregion(color(white))
qui: graph export "km_survival_crude.png", as(png) width(1200) replace
qui: graph export "km_survival_crude.tiff", as(tif) width(3000)replace

//cumulative incidence at each specified year
sts list, failure at(1 3 5 10 15 20) 

**# Cox Proportional Hazard Model (predonation)
//fit cox model
stcox age female pre_hx_htn bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin insurance_pre adi_bin

estimates store main

//globally and by variable, does the proportional hazard hold
//can we assume that these independent variables, is their HR
estat phtest, detail

coefplot, drop(_cons) eform ///
xline(1, lwidth(thin) lpattern(dash) lcolor(red%70)) ///
xlab(0.5 "0.5"  1.0 "1.0" 1.5 "1.5" 2 "2.0" 2.5 "2.5" 3 "3.0", labsize(small)) ///
xscale(log) ///
xtitle("Hazard Ratios and 95% Confidence Intervals" , margin(medsmall)) ///
ylab(1 "Age" ///
2  "Female" ///
3 "Hypertension History" ///
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
qui: graph export "cox_hosp_baseline.png", as(png) width(1200) replace
qui: graph export "cox_hosp_baseline.tiff", as(tif) width(3000) replace
end

//exclude pregnancy hospitalization
//fit cox model
stcox age female pre_hx_htn bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin insurance_pre adi_bin if inlist(hosp_surg_ob_birth, 0, .)


**#interaction of race and ADI
stcox i.adi_bin##i.race_howell age female bmi pre_hx_htn sbp dbp hxsmk egfr_pre income i.edu_whole insurance_pre 
//we get the p-values of interaction from above

//run stratified to understand emm/interaction if significant 
bys race_howell: stcox i.adi_bin


**#Unadjusted Kaplan for Gender & Age
//create age and gender categories
gen sexage = .
	replace sexage=1 if tx_age<55 & !mi(tx_age) & female==0
	replace sexage=2 if tx_age<55 & !mi(tx_age) & female==1
	replace sexage=3 if tx_age>=55 & !mi(tx_age) & female==0
	replace sexage=4 if tx_age>=55 & !mi(tx_age) & female==1

tab sexage
	
	
//fit model
stcox i.sexage pre_hx_htn bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin insurance_pre adi_bin

//plot estimated failure function, by age and gender
stcurve, failure at1(sexage=1) at2(sexage=2) at3(sexage=3) at4(sexage=4) ///
title("Cox Proportional Hazard Regressions", color(black)) ///
subtitle("By Age and Sex") ///
xtitle("Years Post-donation", size(med) margin(medsmall) color(black)) ///
ytitle("Proportion of LKDs Hospitalized (%)") ///
ylab(0 "0" 0.1 "10" 0.2 "20" 0.3 "30" 0.4 "40" 0.5 "50" 0.6 "60" 0.7 "70" , angle(0)) ///
xlab(1 "1" 3 "3" 5 "5" 10 "10" 15 "15" 20 "20") ///
legend(label(1 "Male Age<55") label(2 "Female Age<55") label(3 "Male Age>=55") label(4 "Female Age>=55") size(small)) ///
note("Patients that reported hospitalization, but not year of hospitalization, were excluded (n=72)" ///
"Patients were censored at their survey date" ///
"Adjusting for baseline BMI, systolic and diastolic blood pressure, ever smoke, eGFR, race, household income, 4-year college graduate," "insurance, and area deprivation index", span  size(vsmall)) ///
plotregion(margin(zero)) ///
graphregion(color(white))
graph export "cox_baseline_bysexage.png", as(png) width(1500) replace


sts list, failure at(1 3 5 10 15 20) by(sexage) 
end
**#Unadjusted Kaplan for Age
//create age categories
gen age55 = .
	replace age55=1 if tx_age<55 & !mi(tx_age)
	replace age55=2 if tx_age>=55 & !mi(tx_age)
	
tab age55
	
//fit cox model
stcox age55 female pre_hx_htn bmi sbp dbp hxsmk egfr_pre i.race_howell income not_college_bin insurance_pre adi_bin

//plot estimated failure function, by age
stcurve, failure at1(age55=1) at2(age55=2) ///
title("Unadjusted Kaplan-Meier Failure Curves ", color(black)) ///
subtitle("By Age") ///
xtitle("Years Post-donation", size(med) margin(medsmall) color(black)) ///
ytitle("Proportion of LKDs Hospitalized (%)") ///
ylab(0 "0" 0.1 "10" 0.2 "20" 0.3 "30" 0.4 "40" 0.5 "50" 0.6 "60" , angle(0)) ///
xlab(1 "1" 3 "3" 5 "5" 10 "10" 15 "15" 20 "20") ///
legend(label(1 "Age<55") label(2 "Age>=55")) ///
note("Patients that reported hospitalization, but not year of hospitalization, were excluded (n=72)" ///
"Patients were censored at their survey date", span  size(vsmall)) ///
plotregion(margin(zero)) ///
graphregion(color(white))
graph export "cox_baseline_byage.png", as(png) width(1500) replace


