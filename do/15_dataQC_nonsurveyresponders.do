capture log close _all
capture cmdlog close
clear all 

cd "S:\whole\01_Hospitalization"
global tdate: di %tdCCYYNNDD date(c(current_date),"DMY") 
global cdat: di %tdCCYYNNDD date(c(current_date),"DMY") 
global duedat: di %tdCCYYNNDD date(c(current_date),"DMY")-730 
log using "log_15_dataQC_nonsurveyresponders_${cdat}.log",  replace

clear all
use eligible, clear
merge 1:1 wholeid using whole_demo, nogen keep(master match)
merge 1:1 wholeid using hosp_master, nogen keep(master match) keepusing(hosp_bin)
gen survey_done=!mi(hosp_bin)
	gsort wholeid -survey_done
	bys wholeid: replace survey_done=survey_done[1]


**now make irmatch_whole in preparation to append to irmatch_srtr
keep wholeid tx_age tx_center tx_dt tx_yr female survey_done // 881 (12%) missing age, 3237 (44%) missing gender
tab tx_age if survey_done==0,m //788/4676 (17%) are missing age
tab female if survey_done==0,m //3057/4676 (65%) are missing gender
gen case = 1
drop if mi(tx_center) | tx_center==6
save irmatch_whole_dataQC, replace

**append srtr and whole sets
append using irmatch_srtr
gen id = _n
save irmatch_wholesrtr_dataQC, replace

**table-1 (unmatch)
table1, ///
by(case) ///
vars(tx_yr conts \ tx_center cat \ tx_age conts \ female bin) ///
onecol

save irmatch_wholesrtr_dataQC_working1, replace


*do the irmatch
** var (a (b) c) 
**find exact var match (a radius), if none then find matches within b radius, if still none, then within a b+b radius up to a maximum radius of c
irmatch tx_dt(0(0.4)0.9) tx_center(0(0.4)0.9) female(0(0.5)0.9) tx_age(0(1)2) using irmatch_wholesrtr_dataQC_working1.dta, without ///
	case(case) id(id) seed(423) replace

**# merge
clear all
use irmatch_wholesrtr_dataQC_working1, clear
keep id*
drop if mi(id_ctrl)
rename id_ctrl id
merge 1:1 id using "irmatch_wholesrtr_dataQC.dta", nogen keep(master match)
rename tx* s*
rename female s_female

rename id keyid_srtr
rename id_case id
merge 1:1 id using "irmatch_wholesrtr_dataQC.dta", nogen keep(master match)
rename tx* w*
rename female w_female
rename id keyid_whole

gen diff_txcenter=1 if w_center != s_center
list if diff_txcenter==1 //confirmed exact match

*merge wholeid back in
drop diff_txcenter case survey_done
rename keyid_whole id
drop wholeid
merge 1:1 id using "irmatch_wholesrtr_dataQC.dta", nogen keep(master match) keepusing(wholeid)
rename id keyid_whole
order wholeid donor_id s* w*

lab var donor_id "SRTR LKD ID"
lab var wholeid "WHOLE ID"
merge 1:m wholeid using "irmatch_wholesrtr_dataQC.dta", nogen keep(master match) keepusing(survey_done)


//grab demographics from whole
merge 1:1 wholeid using "whole_demo", nogen keep(master match) keepusing(race hispanic edu hxsmk)
	rename race w_race
	rename edu w_edu
	rename hxsmk w_hxsmk
	rename hispanic w_hispanic
	
//grab last scr from whole
merge 1:1 wholeid using "medhx_lab_master", nogen keep(master match) keepusing(last_pretx_scr last_pretx_bmi pre_hx_dm pre_hx_htn)
	rename last_pretx_* w_*
	rename pre_hx_* w_*

//grab demographics from srtr
merge 1:1 donor_id using "srtr cluster\donor_live.dta", nogen keep(master match) keepusing(*hgt* *wgt* don_race* don_education don_hist_cigarette don_ki_creat* don_hist_hyperten don_hyper* don_diab )
	rename don_ki_creat_preop s_scr
	
	
	//clean up the race variables
	gen s_race=.
	replace s_race = 0 if don_race==8 | don_race_white==1 //white
	replace s_race = 1 if don_race==16 | don_race_black_african_american==1 //black
	replace s_race = 2 if don_race==64 | don_race_asian==1 //Asian
	replace s_race = 2 if don_race==128 | don_race_native_hawaiian==1 //Pacific Islander
	replace s_race = 3 if don_race==32 | don_race_american_indian==1 //Indigenous
	lab var s_race "S Donor Race"
	
	gen s_hispanic=.
	replace s_hispanic=1 if don_race_hispanic_latino==1
	replace s_hispanic=0 if don_race_hispanic_latino==0

	
	//clean up education
	gen s_edu = .
	replace s_edu=0 if don_education==2 //k-8
	replace s_edu = 1 if don_education==3 //high school
	replace s_edu = 3 if don_education==4 | don_education==5 //college/technicalschool/associates/bachelor
	replace s_edu = 4 if don_education==6 //grad
	
	replace w_edu = 3 if w_edu==2 //associates/bachelor
	
	//destring smoking history
gen s_hxsmk = .
	replace s_hxsmk = 0 if don_hist_cigarette=="N"
	replace s_hxsmk = 1 if don_hist_cigarette=="Y"
	
//generate bmi
gen s_bmi = don_wgt_kg/((don_hgt_cm/100)^2) if !mi(don_wgt_kg) & !mi(don_hgt_cm)
	lab var s_bmi "Pre-Op BMI (calculated)" //n=1585 with BMI

//destring hypertension history
gen s_htn = .
	replace s_htn = 0 if inlist(don_hist_hyperten, 1) | don_hyperten_diet=="N" | don_hyperten_diuretics=="N" | don_hyperten_other_meds=="N"
	replace s_htn = 1 if inlist(don_hist_hyperten, 2, 3, 4, 5) | don_hyperten_diet=="Y" | don_hyperten_diuretics=="Y" | don_hyperten_other_meds=="Y" //don_diab_treat were ALL missing
	
//destring diabetes history
gen s_dm = .
	replace s_dm = 0 if don_diab=="N"
	replace s_dm = 0 if don_diab=="Y"
	


foreach v in age female center dt yr race hxsmk scr bmi htn dm hispanic {
gen `v' = s_`v'
	replace `v'= w_`v' if mi(`v') & !mi(w_`v')

}

//create college binary
gen college_bin = .
	replace college_bin = 1 if s_edu>=4 | w_edu>=3
	replace college_bin = 0 if s_edu<4 | w_edu<3
	replace college_bin = . if mi(s_edu) & mi(w_edu)
lab val center tx_center


	//race
gen race_howell = .
	replace race_howell=0 if hispanic==0 & race==0 //non hispanic, white
	replace race_howell=1 if hispanic==1 //any hispanic
	replace race_howell=2 if hispanic==0 & race==1 //non hispanic, black
	replace race_howell=3 if hispanic==0 & race==2 //non hispanic, asian
	replace race_howell=3 if hispanic==0 & race==3 //non hispanic, aian
	replace race_howell=3 if hispanic==0 & race==4 //non hispanic, other
	lab var race_howell "Race: Howell et al"
	lab def race_howell 0 "Nonhispanic White" 1 "Hispanic, Any Race" 2 "Nonhispanic Black" 3 "Nonhispanic Indigenous/Asian/Other", replace
	lab val race_howell race_howell

//calculate ckd-epi
replace scr = w_scr if w_scr>s_scr & !mi(w_scr) & !mi(s_scr)
**calculating PRE-Donation CKD-EPI 2021
gen min = scr/0.7 if female==1
	replace min = scr/0.9 if female==0
	replace min = 1 if min>1 & !mi(min)
	
gen max = scr/0.7 if female==1
	replace max = scr/0.9 if female==0
	replace max = 1 if max<1 & !mi(max)
	
*2021 CKD-EPI FEMALE
gen egfr=142*(min^-0.241)*(max^-1.2)*(0.9938^age)*1.012 ///
	if female==1

*2021 CKD-EPI MALE
replace egfr=142*(min^-0.302)*(max^-1.2)*(0.9938^age) ///
	if female==0
lab var egfr "PRE-Donation CKD-EPI (2021), mL/min/1.73m2, median(IQR)"
format egfr %3.0f
drop min max

//create obese
gen obese=bmi>=30 if !mi(bmi)

//label variables
lab var age "Age at donation, years, median (IQR)"
lab var female "Female, n (%)"
lab var race "Race, n(%)"
lab var college_bin "Four year college educated or above, n (%)"
lab var htn "Pre-donation history of hypertension, n (%)"
lab var dm "Pre-donation history of diabetes, n (%)"
lab var scr "Pre-donation serum creatinine, mg/dL, n (%)"
lab var bmi "BMI, median (IQR)"
lab var hxsmk "Ever smoke, n (%)"

lab def race 0 "White/Caucasian" 1 "Black/African-American" 2 " Asian/Pacific Islander" 3 "American Indian/Alaska Native"
	lab val race race
//lab def edu 0 "K-8" 1 "High school/GED" 3 "College/technical school/associates/bachelor" 4 "Graduate school", replace

merge 1:1 wholeid using eligible, nogen 
merge 1:1 wholeid using hosp_final, nogen keepusing(hosp_bin pre_hx_htn pre_hx_dm)
	replace htn = pre_hx_htn if mi(htn) & !mi(pre_hx_htn)
	replace htn = 1 if pre_hx_htn==1
	replace dm = pre_hx_dm if mi(htn) & !mi(pre_hx_dm)
	replace dm = 1 if pre_hx_dm==1
	
drop survey_done
gen survey_done=!mi(hosp_bin)


save dataQC_nonsurveyresponders_baseline, replace 

table1, ///
by(survey_done) ///
vars(age conts \ female bin \ race_howell cat \ college_bin bin \ htn bin \ dm bin \ scr conts \ obese bin \ bmi conts \ hxsmk bin \ egfr conts) ///
onecol cformat(%3.0f) format(%3.0f) cmissing ///
saving(dataQC_nonsurveyresponders_baseline_${cdat}, replace)

sum scr if survey_done==0 ,d
sum scr if survey_done==1,d