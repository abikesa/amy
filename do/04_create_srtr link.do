capture log close _all
capture cmdlog close
clear all 

cd "S:\whole\01_Hospitalization"
global tdate: di %tdCCYYNNDD date(c(current_date),"DMY") 
global cdat: di %tdCCYYNNDD date(c(current_date),"DMY") 
log using "log_04_srtrlink_${cdat}.log",  replace

**# match wholeid and srtr (donor_id) using center, gender, and date of transplant
///harmonize the variable from string to num
clear all
use "srtr cluster\tx_ki.dta", clear

***harmonize the variables names in the two dataset (ID can stay different, but new id needs to be generated down the line)
keep if don_ty=="L" //keep only live donor
count if don_ty=="L"
keep donor_id don_age_in_months don_age don_gender don_race don_race_srtr don_recov_dt rec_ctr_cd
count if inlist(rec_ctr_cd, "MDJH", "MDUM", "ALUA", "DCGU", "VAMC", "ILNM")
keep if inlist(rec_ctr_cd, "MDJH", "MDUM", "ALUA", "DCGU", "VAMC", "ILNM")

gen tx_center = .
	replace tx_center=0 if rec_ctr_cd=="MDJH"
	replace tx_center=1 if rec_ctr_cd=="MDUM"
	replace tx_center=2 if rec_ctr_cd=="ALUA"
	replace tx_center=3 if rec_ctr_cd=="VAMC"	
	replace tx_center=4 if rec_ctr_cd=="ILNM"
	replace tx_center=5 if rec_ctr_cd=="DCGU"
	lab var tx_center "Transplant Center"
	lab def tx_center 0 "mdjh" 1 "mdum" 2 "alua" 3 "vamc" 4 "ilnm" 5 "dcgu", replace
	lab val tx_center tx_center

gen female=inlist(don_gender, "F") if !mi(don_gender)
	lab def female 0 "male" 1 "female"
	lab val female female
gen tx_yr=year(don_recov_dt) if !mi(don_recov_dt)
rename don_age tx_age
rename don_recov_dt tx_dt

**keep only the variables that you will use to match 
keep donor_id tx_age tx_center tx_dt tx_yr female
order donor_id
gen case = 0
save irmatch_srtr, replace

**now make irmatch_whole in preparation to append to irmatch_srtr
clear all
use "hosp_master.dta"
keep wholeid tx_age tx_center tx_dt tx_yr female // 881 (12%) missing age, 3237 (44%) missing gender
tab tx_age,m
tab female,m
gen case = 1
drop if mi(tx_center) | tx_center==6
save irmatch_whole_hosp, replace

**append srtr and whole sets
append using irmatch_srtr
gen id = _n
save irmatch_wholesrtr_master, replace

**table-1 (unmatch)
table1, ///
by(case) ///
vars(tx_yr conts \ tx_center cat \ tx_age conts \ female bin) ///
onecol

save irmatch_wholesrtr_working1, replace


*do the irmatch
** var (a (b) c) 
**find exact var match (a radius), if none then find matches within b radius, if still none, then within a b+b radius up to a maximum radius of c
irmatch tx_dt(0(0.5)0.9) tx_center(0(0.5)0.9) female(0(0.5)0.9) tx_age(0(1)2) using irmatch_wholesrtr_working1.dta, without ///
	case(case) id(id) seed(423) replace

**# Abi merge
clear all
use irmatch_wholesrtr_working1, clear
drop if mi(id_ctrl) //id_ctrl is srtr
keep id*
list id* in 1/3
save temp0, replace //has id_ctrl and id_case
drop id_case // has id_ctrl (srtr)
rename id_ctrl id
list id in 1/3
save temp1, replace //has srtr only
	
clear
use temp0, clear
list id* in 1/3
drop id_ctrl //has id_case (whole)
rename id_case id
append using temp1
	
isid id
merge 1:1 id using "irmatch_wholesrtr_master.dta", nogen keep(match)

**table 0 (matched)
table1, ///
by(case) ///
vars(tx_yr conts \ tx_center cat \ tx_age conts \ female bin) ///
onecol

**checking
preserve
	drop if case==1
	sort tx_dt
	list in 1/10
restore
preserve
	drop if case==0
	sort tx_dt
	list in 1/10
restore


**# Amy merge
clear all
use irmatch_wholesrtr_working1, clear
keep id*
drop if mi(id_ctrl)
rename id_ctrl id
merge 1:1 id using "irmatch_wholesrtr_master.dta", nogen keep(master match)
rename tx* s*
rename female s_female

rename id keyid_srtr
rename id_case id
merge 1:1 id using "irmatch_wholesrtr_master.dta", nogen keep(master match)
rename tx* w*
rename female w_female
rename id keyid_whole

gen diff_txcenter=1 if w_center != s_center
list if diff_txcenter==1 //confirmed exact match

*merge wholeid back in
drop diff_txcenter case
rename keyid_whole id
drop wholeid
merge 1:1 id using "irmatch_wholesrtr_master.dta", nogen keep(master match) keepusing(wholeid)
rename id keyid_whole
order wholeid donor_id s* w*

lab var donor_id "SRTR LKD ID"
lab var wholeid "WHOLE ID"
save irmatch_wholesrtr_matched, replace


**# merge PRE-donation srtr (donor_live)
//merge with donor_live to get srtr donor history and labs
clear all
use irmatch_wholesrtr_matched, clear
keep donor_id wholeid
merge 1:1 donor_id using "srtr cluster\donor_live.dta", ///
	keepusing(*hgt* *wgt* don_race don_race_srtr don_bp* don_ki_creat*  don_hist_cigarette don_diab don_diab_treat don_hist_hyperten don_hyperten_* pers_ssa_death_dt don_education don_abo don_health_insur don_primary_pay don_priv_insur don_ki_procedure_ty) keep(master match) nogen 

//clean up the race variables
gen srtr_race = .
	replace srtr_race = 0 if strmatch(don_race_srtr, "WHITE")
	replace srtr_race = 1 if strmatch(don_race_srtr, "BLACK")
	replace srtr_race = 2 if strmatch(don_race_srtr, "ASIAN")
	replace srtr_race = 2 if strmatch(don_race_srtr, "PACIFIC")
	replace srtr_race = 3 if strmatch(don_race_srtr, "NATIVE")
	replace srtr_race = 4 if strmatch(don_race_srtr, "MULTI")
	lab var srtr_race "SRTR Donor Race"
	lab def srtr_race 0 "White/Caucasian" 1 "Black/African-American" 2 " Asian/Pacific Islander" 3 "American Indian/Alaska Native" 4 "Multi"
	lab val srtr_race srtr_race
	
//generate bmi
gen don_preop_bmi = don_wgt_kg/((don_hgt_cm/100)^2) if !mi(don_wgt_kg) & !mi(don_hgt_cm)
	lab var don_preop_bmi "Pre-Op BMI (calculated)" //n=1585 with BMI

//destring hypertension history
gen srtr_pre_hx_htn = .
	replace srtr_pre_hx_htn = 0 if inlist(don_hist_hyperten, 1) | don_hyperten_diet=="N" | don_hyperten_diuretics=="N" | don_hyperten_other_meds=="N"
	replace srtr_pre_hx_htn = 1 if inlist(don_hist_hyperten, 2, 3, 4, 5) | don_hyperten_diet=="Y" | don_hyperten_diuretics=="Y" | don_hyperten_other_meds=="Y" //don_diab_treat were ALL missing
	
//destring diabetes history
gen srtr_pre_hx_dm = .
	replace srtr_pre_hx_dm = 0 if don_diab=="N"
	replace srtr_pre_hx_dm = 1 if don_diab=="Y"
		
//destring insurance
gen srtr_pre_insurance = .
	replace srtr_pre_insurance = 0 if don_health_insur=="N" | don_priv_insur=="N" 
	replace srtr_pre_insurance = 1 if don_health_insur=="Y" | don_priv_insur=="Y" | inrange(don_primary_pay, 1, 7)
	
//type of insurnace
gen srtr_pre_insurance_type = .
	replace srtr_pre_insurance_type = 1 if inlist(don_primary_pay, 1) //private insurance
	replace srtr_pre_insurance_type = 2 if inlist(don_primary_pay, 2, 3, 4, 5, 6, 7, 12, 13) //public insurance, does not include self or donation
	
//procedure type
gen open =.
	replace open=1 if inlist(don_ki_procedure_ty, 1, 2)
	replace open=0 if inlist(don_ki_procedure_ty, 3, 4, 5)

	
	
save matched_srtr_pre, replace

**merge POST-donation srtr (don_liv_fol)
clear all
use irmatch_wholesrtr_matched, clear
keep wholeid donor_id
merge 1:m donor_id using "srtr cluster\don_liv_fol.dta",	///
	keepusing(dfl_fol_cd dfl_ki_creat  dfl_px_stat_dt dfl_px_stat dfl_cod dfl_cod_ostxt dfl_diab dfl_diab_treat dfl_hyperten dfl_anti_hyperten_drug dfl_urine_protein dfl_urine_ratio) keep(master match) nogen 	
	
gen don_status=.
	replace don_status=0 if strmatch(dfl_px_stat, "D") | strmatch(dfl_px_stat, "6")
	replace don_status=1 if strmatch(dfl_px_stat, "1") | strmatch(dfl_px_stat, "2") | strmatch(dfl_px_stat, "3") | strmatch(dfl_px_stat, "4") | strmatch(dfl_px_stat, "5")
	replace don_status=2 if strmatch(dfl_px_stat, "L") | strmatch(dfl_px_stat, "7") | strmatch(dfl_px_stat, "8")
	lab var don_status "SRTR status"
	lab def don_status 0 "dead" 1 "alive" 2 "lost to follow-up"
	
**6m creatinine
gsort wholeid dfl_fol_cd
gen scr_6m=dfl_ki_creat if dfl_fol_cd==6

gsort wholeid -scr_6m
bys wholeid: gen scr_6m_srtr=scr_6m[1]

**diabetes history
gen srtr_dm =.
	replace srtr_dm=0 if dfl_diab=="N"
	replace srtr_dm=1 if dfl_diab=="Y"
	
gsort wholeid -srtr_dm dfl_fol_cd
by wholeid: gen srtr_post_hx_dm = srtr_dm[1]

gsort wholeid -srtr_dm dfl_fol_cd
by wholeid: gen srtr_post_hx_dm_yr = dfl_fol_cd[1]
	replace srtr_post_hx_dm_yr=0.5 if srtr_post_hx_dm_yr==6
	replace srtr_post_hx_dm_yr=1 if srtr_post_hx_dm_yr==10
	replace srtr_post_hx_dm_yr=2 if srtr_post_hx_dm_yr==20

**hypertension history
gen srtr_htn =.
	replace srtr_htn=0 if dfl_hyperten=="N" | dfl_anti_hyperten_drug==0
	replace srtr_htn=1 if dfl_hyperten=="Y" | dfl_anti_hyperten_drug==1
	
gsort wholeid -srtr_htn dfl_fol_cd
by wholeid: gen srtr_post_hx_htn = srtr_htn[1]

gsort wholeid -srtr_htn dfl_fol_cd
by wholeid: gen srtr_post_hx_htn_yr = dfl_fol_cd[1]
	replace srtr_post_hx_htn_yr=0.5 if srtr_post_hx_htn_yr==6
	replace srtr_post_hx_htn_yr=1 if srtr_post_hx_htn_yr==10
	replace srtr_post_hx_htn_yr=2 if srtr_post_hx_htn_yr==20
	
keep wholeid scr_6m_srtr srtr_post_hx_dm srtr_post_hx_dm_yr srtr_post_hx_htn srtr_post_hx_htn_yr
keep if !mi(scr_6m_srtr) | !mi(srtr_post_hx_dm) | !mi(srtr_post_hx_htn)
duplicates drop

save matched_srtr_post, replace
