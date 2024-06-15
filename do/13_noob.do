capture log close _all
capture cmdlog close
clear all 

cd "S:\whole\01_Hospitalization"
global cdat: di %tdCCYYNNDD date(c(current_date),"DMY") 
log using "log_13_noob_${cdat}.log",  replace

//this is to create a sheet for all hospitalization except delivery or c section
**#Hospitalization (Abi) 20220712
clear all
use hosp_master_noob, clear

**must be from the 5 centers and a transplant date
drop if mi(tx_center) | tx_center==6
drop if mi(tx_dt) & mi(tx_yr)

//education
recode edu (0=2) (2=1) (3=0) (4=0), gen(edu_whole)
	lab var edu_whole "Education Level (WHOLE)"
	lab def edu_whole 0 "bachelor or above" 1 "high school" 2 "k-8"
	lab val edu_whole edu_whole

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

//demo, post donation history and insurance
merge 1:1 wholeid using "medhx_lab_master.dta", nogen keep(master match) //post-donation history, insurance

//confirm post-donation mhx is PRE-hospitalization
foreach mhx in htn dm ckd cancer {
	replace post_hx_`mhx'=0 if post_hx_`mhx'_yr<0
	replace post_hx_`mhx'_yr=. if post_hx_`mhx'_yr<0
}

tab post_hx_htn hosp_bin, col
tab post_hx_dm hosp_bin, col

//adi
merge 1:1 wholeid using "matched_adi.dta", keep(master match) keepusing(adi_natrank) nogen
	sum adi_natrank,d 
	
	gen adi_bin=adi_natrank>=38 if !mi(adi_natrank)
	lab var adi_bin "Disadvantaged Area Deprivation Index (>=38 Median)"
	
	gen adi_cat = .
	replace adi_cat = 1 if adi_natrank<20 & !mi(adi_natrank)
	replace adi_cat = 2 if adi_natrank>=20 & adi_natrank<38 & !mi(adi_natrank)
	replace adi_cat = 3 if adi_natrank>=38 & adi_natrank<60 & !mi(adi_natrank)
	replace adi_cat = 4 if adi_natrank>=60 & !mi(adi_natrank)
	lab var adi_cat "ADI Categ (Median and Quartiles)"
	lab def adi_cat 0 "1st quart: <20" 1 "2nd quart: 21-37" 2 "3rd quart: 38-59" 3 ">60"

	
//srtr
merge 1:1 wholeid using matched_srtr_pre.dta, keep(master match) nogen
	replace pre_hx_dm = srtr_pre_hx_dm if mi(pre_hx_dm) & !mi(srtr_pre_hx_dm)
	replace pre_hx_dm = 1 if srtr_pre_hx_dm==1
	replace pre_hx_htn = srtr_pre_hx_htn if mi(pre_hx_htn) & !mi(srtr_pre_hx_htn)
	replace pre_hx_htn = 1 if srtr_pre_hx_htn==1
	
	replace last_pretx_sbp =  don_bp_preop_syst if mi(last_pretx_sbp) & !mi(don_bp_preop_syst)
	replace last_pretx_sbp =  don_bp_preop_syst if don_bp_preop_syst>last_pretx_sbp
	
	replace last_pretx_dbp =  don_bp_preop_diast if mi(last_pretx_dbp) & !mi(don_bp_preop_diast)
	replace last_pretx_dbp =  don_bp_preop_diast if don_bp_preop_diast>last_pretx_dbp
	
	replace last_pretx_bmi =  don_preop_bmi if mi(last_pretx_bmi) & !mi(don_preop_bmi)
	replace last_pretx_bmi =  don_preop_bmi if don_preop_bmi>last_pretx_bmi
	
	replace last_pretx_scr =  don_ki_creat_preop if mi(last_pretx_scr) & !mi(don_ki_creat_preop)
	replace last_pretx_scr =  don_ki_creat_preop if don_ki_creat_preop>last_pretx_scr
	
	replace hxsmk = 1 if strmatch(don_hist_cigarette, "Y")

	gen edu_srtr = .
		replace edu_srtr = 0 if inlist(don_education, 4, 5, 6) //bachelor or above
		replace edu_srtr = 1 if don_education==3 //high school
		replace edu_srtr = 2 if don_education==2 //k-8
		lab var edu_srtr "Education Level (SRTR)"
		lab def edu_srtr 0 "bachelor or above" 1 "high school" 2 "k-8"
		lab val edu_srtr edu_srtr
		
		
//srtr post-donation hx
merge 1:1 wholeid using "matched_srtr_post", nogen keep(master match) keepusing(srtr_post_hx_*)

//clean up the years to match the post-donation diagnosis
replace srtr_post_hx_htn_yr=. if inlist(srtr_post_hx_htn, 0, .)
replace srtr_post_hx_dm_yr=. if inlist(srtr_post_hx_dm, 0, .)
		
replace post_hx_htn=1 if srtr_post_hx_htn==1 
replace post_hx_htn_yr=srtr_post_hx_htn_yr if mi(post_hx_htn_yr) & !mi(srtr_post_hx_htn_yr)
replace post_hx_htn_yr=srtr_post_hx_htn_yr if srtr_post_hx_htn_yr<post_hx_htn_yr

replace post_hx_dm=1 if srtr_post_hx_dm==1 
replace post_hx_dm_yr=srtr_post_hx_dm_yr if mi(post_hx_dm_yr) & !mi(srtr_post_hx_dm_yr)
replace post_hx_dm_yr=srtr_post_hx_dm_yr if srtr_post_hx_dm_yr<post_hx_dm_yr

//NEW htn and dm post-donation
gen new_post_htn=0
	replace new_post_htn=1 if pre_hx_htn==0 & post_hx_htn==1
	gen new_post_htn_yr=post_hx_htn_yr if new_post_htn==1

gen new_post_dm=0
	replace new_post_dm=1 if pre_hx_dm==0 & post_hx_dm==1
	gen new_post_dm_yr=post_hx_dm_yr if new_post_dm==1
	


*merging history into systems
egen post_hx_cv = rowmax(post_hx_chf post_hx_cad post_hx_ath post_hx_htn post_hx_pvd post_hx_stroke post_hx_mi)

**calculating PRE-Donation CKD-EPI 2021
gen min = last_pretx_scr/0.7 if female==1
	replace min = last_pretx_scr/0.9 if female==0
	replace min = 1 if min>1 & !mi(min)
	
gen max = last_pretx_scr/0.7 if female==1
	replace max = last_pretx_scr/0.9 if female==0
	replace max = 1 if max<1 & !mi(max)
	
*2021 CKD-EPI FEMALE
gen ckdepi_pre=142*(min^-0.241)*(max^-1.2)*(0.9938^tx_age)*1.012 ///
	if female==1

*2021 CKD-EPI MALE
replace ckdepi_pre=142*(min^-0.302)*(max^-1.2)*(0.9938^tx_age) ///
	if female==0
lab var ckdepi_pre "PRE-Donation CKD-EPI (2021)"
format ckdepi_pre %3.0f
drop min max


//label demographics
lab var open "Open (Transabdominal or retroperitoneal) nephrectomy"
lab var tx_age "Age at donation nephrectomy, years"
lab var female "Female"
lab var white "White"
lab var black "Black"
lab var hispanic "Hispanic"
lab var race "Self-reported Race"
	lab def race 0 "White" 1 "Black" 2 "Asian/Pacific Islander" 3 "American Indian/Alaska Native" 4 "Other", replace
lab var hxsmk "Ever smoked in lifetime, yes/no"
	lab def hxsmk 0 "never smoked" 1 "Ever smoked"
lab var hxetoh "Ever EtOH"
lab var hxsubstance "Ever used substances"
lab var tx_center "Transplant center"
lab def tx_center 0 "Hopkins" 1 "U Maryland" 2 "UAB" 3 "VCU" 4 "Northwestern" 5 "Georgetown" 6 "other", replace
lab var hosp_bin "Reported being hospitalized since donation, yes/no"

lab var srtr_pre_insurance_type "Predonation Insurance Type"
	lab def srtr_pre_insurance_type 0 "private" 1 "public"
	lab val srtr_pre_insurance_type srtr_pre_insurance_type
//label hospital causes
lab var hosp_surg_any "Surgery: Any"
lab var hosp_surg_ortho "Surgery: Ortho"
lab var hosp_surg_gyn "Surgery: Gynecoloy"
lab var hosp_surg_ob_birth "Surgery: Delivery or C Section"
lab var hosp_surg_breast "Surgery: Breast"
lab var hosp_surg_gi "Surgery: GI"
lab var hosp_surg_other "Surgery: Other"

lab var hosp_cv "Hospitalization related to cardiovascular condition or symptom"
lab var hosp_resp "Hospitalization related to respiratory condition or symptom"
lab var hosp_derm "Hospitalization related to dermatologic condition or symptom"
lab var hosp_msk "Hospitalization related to musculoskeletal condition or symptom"
lab var hosp_renal "Hospitalization related to kidney concerns or abnormal creatinine"
lab var hosp_uro_male "Hospitalization related to male genitourinary condition or symptom"
lab var hosp_breast "Hospitalization related to breast condition or symptom"
lab var hosp_uro_female "Hospitalization related to female genitourinary condition or symptom"
lab var hosp_preg "Hospitalization related to pregnancy (excluding delivery or C section)"
lab var hosp_neo "Hospitalization related to any neoplasm (benign or malignant)"
lab var hosp_inf "Hospitalization related to infectious disease"
lab var hosp_gi "Hospitalization related to digestive system"
lab var hosp_ob_hemodynamics "Hospitalization related to preeclampsia/eclampsia"
lab var hosp_heme "Hospitalization related to hematologic condition or symptom"
lab var hosp_endo "Hospitalization related to endocrine system"
lab var hosp_psych "Hospitalization related to psychiatric condition or symptom"
lab var hosp_neuro "Hospitalization related to nervous system"
lab var hosp_ent "Hospitalization related to ear, nose, throat condition or symptoms"
lab var hosp_postop_comp "Hospitalization related to post-operative complication (related to either donation or other procedures)"
lab var hosp_fall "Hospitalization related to fall"
lab var hosp_hernia "Hospitalization related to hernia"
lab var hosp_other "Hospitalization related to other conditions or complaints (eg car accident, meckel's diverticulum, fever)"

//label history
lab var last_pretx_sbp "Baseline systolic BP, mmHg"
lab var last_pretx_dbp "Baseline diastolic BP, mmHg"
lab var last_pretx_bmi "Baseline BMI, kg/m2"
lab var pre_hx_dm "Baseline Diabetes History"
lab var pre_hx_htn "Baseline Hypertension History"


//edit to reflect REDCap
replace hosp_bin=1 if wholeid=="BQ743" 
replace hosp_bin=1 if wholeid=="VY854" 


save hosp_final_noob.dta, replace