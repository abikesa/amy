capture log close _all
capture cmdlog close
clear all 

cd "S:\whole\01_Hospitalization"
global tdate: di %tdCCYYNNDD date(c(current_date),"DMY") 
global cdat: di %tdCCYYNNDD date(c(current_date),"DMY") 
log using "log_02_mhx_labs_${cdat}.log",  replace



**# preop scr
clear all
use whole_crude_01.dta, clear
keep wholeid preop_scr_date preop_scr
egen tag=rownonmiss(preop_scr_date preop_scr)
drop if tag==0
drop tag

rename preop_scr_date cmp_date
rename preop_scr cmp_scr
gen labno=-1

append using whole_cmp.dta
keep wholeid cmp_date cmp_scr
duplicates drop

merge m:1 wholeid using "whole_demo.dta", nogen keep(master match) keepusing(tx_dt)
gen time = cmp_date-tx_dt

gen time_pre=time if inrange(time, -15, 0)
gen time_6m=time if inrange(time, 150, 210)

gen scr_pre=cmp_scr if !mi(time_pre)
gen scr_6m=cmp_scr if !mi(time_6m)

drop if mi(scr_pre) & mi(scr_6m)

gsort wholeid -scr_pre
by wholeid: gen last_pretx_scr=scr_pre[1]
by wholeid: replace time_pre=time_pre[1]

gsort wholeid -scr_6m
by wholeid: replace scr_6m=scr_6m[1]
by wholeid: replace time_6m=time_6m[1]

keep wholeid time_* last_pretx_scr scr_6m
order wholeid time_pre last_pretx_scr time_6m scr_6m
duplicates drop

save scr_pre_6m.dta, replace


**# preop ht, wt, bmi
clear all
use whole_crude_01.dta, clear
keep wholeid preop_height_date preop_height_in preop_height_cm preop_weight_date preop_weight_lb preop_weight_kg preop_bmi
egen tag=rownonmiss(preop_height_date preop_height_in preop_height_cm preop_weight_date preop_weight_lb preop_weight_kg preop_bmi)
drop if tag==0

replace preop_weight_date=preop_height_date if mi(preop_weight_date) & !mi(preop_height_date)
drop preop_height_date

rename preop_weight_date vs_date
rename preop_height_in vs_htin
rename preop_height_cm vs_htcm
rename preop_weight_lb vs_wtlb
rename preop_weight_kg vs_wtkg
rename preop_bmi vs_bmi

drop tag
gen labno=-1

append using whole_vs.dta
keep wholeid vs_date vs_bmi vs_w* vs_h*
duplicates drop

*calculate bmi
replace vs_htcm = vs_htin*2.54 if mi(vs_htcm) & !mi(vs_htin)
replace vs_wtkg = vs_wtlb/2.205 if mi(vs_wtkg) & !mi(vs_wtlb)
replace vs_bmi=vs_wtkg/((vs_htcm/100)^2) if mi(vs_bmi)

merge m:1 wholeid using "whole_demo.dta", nogen keep(master match) keepusing(tx_dt)
gen time = vs_date-tx_dt

gen time_pre=time if time<0
drop if mi(time_pre)
drop if mi(vs_bmi)

gsort wholeid time_pre -vs_bmi
bys wholeid: gen last_pretx_bmi=vs_bmi[1]
keep wholeid last_pretx_bmi
duplicates drop

save bmi_pre.dta, replace


**# preop bp
clear all
use whole_crude_01.dta, clear
keep wholeid preop_bp_date preop_sys preop_dias preop_bp_date2 preop_sys2 preop_dias2 preop_bp_date3 preop_sys3 preop_dias3
egen tag=rownonmiss(preop_bp_date preop_sys preop_dias preop_bp_date2 preop_sys2 preop_dias2 preop_bp_date3 preop_sys3 preop_dias3)
drop if tag==0

rename preop_bp_date preop_bp_date1
rename preop_sys preop_sys1
rename preop_dias preop_dias1

duplicates drop
drop if wholeid=="KT875" & mi(preop_bp_date2) //found duplicates for some reason
drop if wholeid=="QV652" & mi(preop_bp_date2) //found duplicates for some reason

reshape long preop_bp_date preop_sys preop_dias, i(wholeid) j(num)
drop tag
drop num

rename preop_bp_date vs_date
rename preop_sys vs_sbp
rename preop_dias vs_dbp
gen labno=-1
drop if mi(vs_date) & mi(vs_sbp) & mi(vs_dbp)


append using whole_vs.dta
keep wholeid vs_date vs_sbp vs_dbp
duplicates drop

merge m:1 wholeid using "whole_demo.dta", nogen keep(master match) keepusing(tx_dt)
gen time = vs_date-tx_dt

gen time_pre=time if time<0
drop if mi(time_pre)
drop if mi(vs_sbp) & mi(vs_dbp)

gsort wholeid -time_pre -vs_sbp
bys wholeid: gen last_pretx_sbp=vs_sbp[1]

gsort wholeid -time_pre -vs_dbp
bys wholeid: gen last_pretx_dbp=vs_dbp[1]

keep wholeid last_pretx_*
duplicates drop

save bloodpressure_pre.dta, replace


**# POST MHx (Survey)
clear all
use whole_crude_01.dta, clear
rename s1_proteinurea s1_proteinu

*variables for medical history: s1_ckd s1_heme s1_lung s1_chf s1_cad s1_ath s1_hyperlip s1_htn s1_pvd s1_proteinu s1_thy s1_cva s1_tia s1_dm s1_cancer s1_mi       sf_ckd sf_heme sf_lung sf_chf sf_cad sf_ath sf_hyperlip sf_htn sf_pvd sf_proteinu sf_thy sf_cva sf_tia sf_dm sf_cancer sf_mi 

keep if info_type==1 //keep all surveys

foreach v of varlist s1_ckd s1_heme s1_lung s1_chf s1_cad s1_ath s1_hyperlip s1_htn s1_pvd s1_proteinu s1_thy s1_cva s1_tia s1_dm s1_cancer s1_mi sf_ckd sf_heme sf_lung sf_chf sf_cad sf_ath sf_hyperlip sf_htn sf_pvd sf_proteinu sf_thy sf_cva sf_tia sf_dm sf_cancer sf_mi s1_hi_before s1_hi_now sf_hi_now d_preg_after {
	replace `v' = . if inlist(`v', 2, 3)
}

foreach mhx in ckd proteinu heme lung chf cad ath hyperlip htn pvd thy cva tia dm cancer mi hi_now {
	egen tot_`mhx' = rowmax(s1_`mhx' sf_`mhx')
	gsort wholeid -tot_`mhx'
	by wholeid: gen post_hx_`mhx' = tot_`mhx'[1]
	drop tot_`mhx'
}

//s1_hi_before
	egen tot_hi_before = rowmax(s1_hi_before)
	gsort wholeid -tot_hi_before
	by wholeid: gen insurance_pre = tot_hi_before[1]
	drop tot_hi_before

**year of diagnosis (ckd, htn, dm, cancer)
replace sf_ckd_yr = 2011 if sf_ckd_yr==11
	replace sf_ckd_yr = 2020 if sf_ckd_yr==20

replace s1_htn_yr=. if s1_htn_yr==0
	replace sf_htn_yr = "" if sf_htn_yr=="0000"
	replace sf_htn_yr = "2012" if sf_htn_yr == "11/2012" 
	replace sf_htn_yr = "2016" if sf_htn_yr ==  "12/1/2016" 
	replace sf_htn_yr = "" if sf_htn_yr ==  "150 90" 
	replace sf_htn_yr = "2007" if sf_htn_yr == "2007, no longer a problem" 
	replace sf_htn_yr = subinstr(sf_htn_yr, "?","",.)
	destring sf_htn_yr, gen(_sf_htn_yr) force
	drop sf_htn_yr
	rename _sf_htn_yr sf_htn_yr

replace sf_dm_yr = "2015" if sf_dm_yr == "06-10-2015" 
	replace sf_dm_yr = "2005" if sf_dm_yr == "2005?"
	destring sf_dm_yr, gen(_sf_dm_yr) force
	drop sf_dm_yr
	rename _sf_dm_yr sf_dm_yr

replace sf_cancer_yr = "2002" if sf_cancer_yr=="2002 and 2006"
	replace sf_cancer_yr = "2005" if sf_cancer_yr=="2020"
	replace sf_cancer_yr = "2006" if sf_cancer_yr=="2006; 2010;2016"
	replace sf_cancer_yr = "2010" if sf_cancer_yr=="2010-2017"
	replace sf_cancer_yr = "2010" if sf_cancer_yr=="2010; 2010"
	replace sf_cancer_yr = "2017" if sf_cancer_yr=="2017 and 2020"
	replace sf_cancer_yr = "2018" if sf_cancer_yr=="2018 and 2020"
	replace sf_cancer_yr = "2015" if sf_cancer_yr=="Dec 2015"
	replace sf_cancer_yr = "2010" if sf_cancer_yr=="Twice since 2010"	
	destring sf_cancer_yr, gen(_sf_cancer_yr) force
	drop sf_cancer_yr
	rename _sf_cancer_yr sf_cancer_yr
	
foreach mhxyr in ckd htn dm cancer  {
	egen `mhxyr'_min = rowmin(s1_`mhxyr'_yr sf_`mhxyr'_yr)
	gsort wholeid `mhxyr'_min
	by wholeid: gen post_hx_`mhxyr'_yr = `mhxyr'_min[1]
	drop `mhxyr'_min
}

//post-donation pregnancy
	gsort wholeid -d_preg_after
	by wholeid: gen post_hx_preg = d_preg_after[1]
	drop d_preg_after

keep wholeid post_hx_* post_hx_*_yr insurance_pre 
duplicates drop
unique wholeid

merge 1:1 wholeid using "whole_demo.dta", nogen keep(master match) keepusing(tx_yr)

foreach mhxyr in ckd htn dm cancer  {
	replace post_hx_`mhxyr'_yr = post_hx_`mhxyr'_yr - tx_yr if !mi(post_hx_`mhxyr'_yr) & !mi(tx_yr)
	replace post_hx_`mhxyr' = 1 if !mi(post_hx_`mhxyr'_yr)
	lab var post_hx_`mhxyr'_yr "Years of `mhxyr' relative to date of donation"
}


egen post_hx_stroke = rowmax(post_hx_cva post_hx_tia)

foreach mhx in ckd heme lung chf cad ath hyperlip htn pvd thy stroke dm cancer mi preg {
	lab var post_hx_`mhx' "POST-donation diagnosis of `mhx'"
}

rename post_hx_hi_now insurance_post
lab var insurance_post "Have POST-donation insurance"
lab var insurance_pre "Have AT donation insurance"

save survey_post_mhx, replace

**# Pre-donation MHx from WHOLE-Donor
clear all
use whole_crude_01.dta, clear

keep wholeid preop_hx_dm preop_hx_htn preop_dmrx 
replace preop_hx_dm=. if preop_hx_dm==2
replace preop_hx_htn=. if preop_hx_htn==2

keep if !mi(preop_hx_dm) | !mi(preop_hx_htn) | !mi(preop_dmrx)

merge m:1 wholeid using "survey_post_mhx.dta", nogen keep(master match)

egen _dm=rowmax(preop_hx_dm preop_dmrx)
gsort wholeid -_dm 
bys wholeid: gen pre_hx_dm=_dm[1]
	replace pre_hx_dm=1 if post_hx_dm_yr<0 & !mi(post_hx_dm_yr)
	
gsort wholeid -preop_hx_htn
bys wholeid: gen pre_hx_htn=preop_hx_htn[1]
	replace pre_hx_htn=1 if post_hx_htn_yr<0 & !mi(post_hx_htn_yr)

keep wholeid pre_hx_*
duplicates drop

save survey_pre_mhx, replace

**# merge all
clear all
use survey_pre_mhx, clear
count
merge 1:1 wholeid using "survey_post_mhx.dta", nogen keep(master match using)
count
merge 1:1 wholeid using "scr_pre_6m.dta", nogen keep(master match using)
count
merge 1:1 wholeid using "bmi_pre.dta", nogen keep(master match using)
count
merge 1:1 wholeid using "bloodpressure_pre.dta", nogen keep(master match using)
count

save medhx_lab_master, replace