capture log close _all
capture cmdlog close
clear all 

cd "S:\whole\01_Hospitalization"
global tdate: di %tdCCYYNNDD date(c(current_date),"DMY") 
global cdat: di %tdCCYYNNDD date(c(current_date),"DMY") 
global duedat: di %tdCCYYNNDD date(c(current_date),"DMY")-730 
log using "log_01_create_demo_adi_${cdat}.log",  replace

*****************************************************
* Project Title: WHOLE                              
* Author: Amy Chang   
*****************************************************

* Import crude file and change the ID from string to integer
clear all
use "whole_crude.dta", clear
drop if wholeid=="TEST"
drop if wholeid=="SP595"
drop if mi(wholeid)

replace wholeid=strupper(wholeid)

* Replace all string dates to int date
foreach v of varlist post_*date* preop_*date* preop_*date {
	tostring `v', replace
	gen _date_ = date(`v', "MDY", 2022)
	label var _date_ "`v'"
	drop `v'
	rename _date_ `v'
	format `v' %dM_d,_CY
}


* Rename dates
* Some "date" vars were actually years, so changed accordingly
* Changed tx_date to allow loop search for "date"
rename s*_ootx_date s*_ootx_yr
rename s*_ckd_date s*_ckd_yr
rename s*_ktx_date s*_ktx_yr
rename s1_erdate* s1_eryr*
rename sf_erdate* sf_eryr*
rename s1_hospdate* s1_hospyr*
rename sf_hospdate* sf_hospyr*
rename tx_date tx_dt

* Encode REDCap event
encode redcap_event_name, gen(x)
replace x=0 if strpos(redcap_event_name, "data_import_arm_") 
replace x=1 if strpos(redcap_event_name, "survey_1_arm_")
replace x=2 if strpos(redcap_event_name, "followup_1_arm_")
replace x=3 if strpos(redcap_event_name, "followup_2_arm_")
replace x=4 if strpos(redcap_event_name, "followup_3_arm_")
replace x=5 if strpos(redcap_event_name, "followup_4_arm_")
replace x=6 if strpos(redcap_event_name, "postop_tx_center_") 
replace x=7 if strpos(redcap_event_name, " mr_abstraction1_") | strpos(redcap_event_name, "mr_abstraction_1_arm_") | strpos(redcap_event_name, "mr_abstraction1_arm_6")
replace x=8 if strpos(redcap_event_name, "mr_abstraction_2_arm_")
replace x=9 if strpos(redcap_event_name, "mr_abstraction_3_arm_")
replace x=10 if strpos(redcap_event_name, "mr_abstraction_4_arm_")
replace x=11 if strpos(redcap_event_name, "mr_abstraction_5_arm_")
replace x=12 if strpos(redcap_event_name, "hypertensive_test_arm_")
replace x=13 if strpos(redcap_event_name, "weight_loss_arm_")
rename x rdc_row
	lab def rdc_row 0 "dataimport" 1 "s1" 2 "fu1" 3 "fu2" 4 "fu3" 5 "fu4" ///
		6 "mr_postop" 7 "mr1" 8 "mr2" 9 "mr3" 10 "mr4" 11 "mr5" ///
		12 "mod H" 13 "mod wgt loss" , replace
	lab val rdc_row rdc_row

gen info_type = .
replace info_type = 0 if strpos(redcap_event_name, "data_import_arm_")
replace info_type = 1 if inrange(rdc_row, 1, 5)
replace info_type = 2 if inrange(rdc_row, 7, 11)
replace info_type = 3 if inlist(rdc_row, 12)
replace info_type = 4 if inlist(rdc_row, 13)
lab def info_type 0 "dataimport" 1 "surveys" 2 "mrabstraction" 3 "module H" 4 "module weightloss", replace
lab val info_type info_type
	
save whole_crude_01, replace

**# Demographics
clear all
use whole_crude_01, clear
* Donor transplant center
gen center = .
	replace center=0 if tx_center=="MDJH"
	replace center=1 if tx_center=="MDUM"
	replace center=2 if tx_center=="ALUA"
	replace center=3 if tx_center=="VAMC"
	replace center=4 if tx_center=="ILNM"
	replace center=5 if tx_center=="DCGU"
	replace center=6 if tx_center=="OTHER"
	tab tx_center center
	drop tx_center
	rename center tx_center
	
gsort wholeid tx_center
bys wholeid: replace tx_center=tx_center[1]


* Donor age
replace tx_year = year(tx_dt) if mi(tx_year) & !mi(tx_dt)
replace dob_year = year(dob) if mi(dob_year) & !mi(dob)

gen tx_age = (tx_dt-dob)/365.25 if !mi(tx_dt) & !mi(dob)
replace tx_age = tx_year-dob_year if mi(tx_age) & !mi(dob_year) & !mi(tx_year)

gsort wholeid -tx_age
bys wholeid: replace tx_age = tx_age[1] 
format tx_age %3.1f

* Transplant date - propagate to fill all rows
gsort wholeid -tx_dt
bys wholeid: gen _txdt = tx_dt[1]
format _txdt %dM_d,_CY

gsort wholeid -tx_year
bys wholeid: gen _txyr = tx_year[1]
drop tx_dt tx_year
rename _txdt tx_dt
rename _txyr tx_yr
lab var tx_yr "Year of transplant donation surgery"
lab var tx_dt "Date of donation surgery"

tab tx_center if rdc_row==0 & (mi(tx_dt) & mi(tx_yr))
tab tx_center if rdc_row==0 & (mi(dob) & mi(dob_year))
tab tx_center if rdc_row==0 & mi(tx_age)

* Gender
replace gender=. if gender==2
replace s1_gender=. if s1_gender==2
gsort wholeid gender
bys wholeid: replace gender=gender[1]

gsort wholeid s1_gender
bys wholeid: replace s1_gender=s1_gender[1]

replace s1_gender=gender if mi(s1_gender) & !mi(gender)

recode s1_gender (0=1) (1=0)
	rename s1_gender female
	lab var female "Female"
	lab def female 0 "male" 1 "female"
lab val female female

* Race
replace s1_race=. if s1_race==5 // option 5 is "declined to answer"
replace race=. if race==5
	
* African American
gen black=inlist(s1_race, 1) if !mi(s1_race) 
replace black=inlist(race, 1) if mi(black) & !mi(race)

* White
gen white=inlist(s1_race, 0) if !mi(s1_race) 
replace white=inlist(race, 0) if mi(white) & !mi(race)

* Hispanic
replace s1_hisp=. if s1_hisp==2 // option 2 is "declined to answer"
replace hisp=. if hisp==2
gen hispanic=inlist(hisp, 1) if !mi(s1_hisp) 
replace hispanic=inlist(hisp, 1) if mi(hispanic) & !mi(hisp)

* Overall race
egen eth=rowmax(s1_race race)
	gsort wholeid eth
	bys wholeid: gen _eth=eth[1]
	drop race eth
	rename _eth race
	lab def race 0 "white" 1 "AA" 2 "Asian/pacific islander" 3 "AIAN" 4 "other", replace
	lab val race race

foreach n in black white hispanic{
	gsort wholeid -`n'
	bys wholeid: gen _`n'=`n'[1]
	drop `n'
	rename _`n' `n'
}

keep wholeid tx_center tx_dt tx_yr tx_age female race white black hispanic 

foreach v in tx_center tx_dt tx_yr tx_age female race white black hispanic  {
	gsort wholeid -tx_center
	bys wholeid: gen _`v' = `v'[1]
	drop `v'
	rename _`v' `v'
}
duplicates drop
format tx_dt %td
isid wholeid


	lab var tx_center "Transplant Center"
	lab def tx_center 0 "mdjh" 1 "mdum" 2 "alua" 3 "vamc" 4"ilnm" 5 "dcgu" 6 "other", replace
	lab val tx_center tx_center

save whole_demo, replace

**# education
clear all
use whole_crude_01.dta, clear
keep wholeid s1_edu sf_edu
drop if mi(s1_edu) & mi(sf_edu)
duplicates drop

replace s1_edu=. if s1_edu==5
replace sf_edu=. if sf_edu==5
gen edu=max(s1_edu, sf_edu)
	gsort wholeid -edu
	bys wholeid: replace edu=edu[1]
	lab var edu "highest education level"
	lab def edu 0 "k-8" 1 "high school" 2 "associates" 3 "bachelor" 4 "graduate"
	lab val edu edu

keep wholeid edu
duplicates drop

gen college_bin = .
	replace college_bin=0 if inlist(edu, 0, 1, 2)
	replace college_bin=1 if inlist(edu, 3 , 4)
	lab var college_bin "4 year college educated"
merge 1:1 wholeid using "whole_demo.dta", nogen keep(using match)
save whole_demo, replace

/*
**# zipcode and income
clear all
use whole_crude_01.dta, clear
keep wholeid zip
drop if mi(zip)
duplicates drop
destring zip, replace force float
merge 1:1 wholeid using whole_demo, nogen keep(using match)
save whole_demo, replace
*/

**# smoking, etoh, substance
clear all
use whole_crude_01.dta, clear
**Smoking history
foreach v in s1_eversmoke s1_nowsmoke sf_eversmoke sf_nowsmoke preop_hx_eversmoke preop_hx_evalsmoke {
	replace `v'=. if `v'==2
}

egen _smk = rowmax(s1_eversmoke s1_nowsmoke sf_eversmoke sf_nowsmoke preop_hx_eversmoke preop_hx_evalsmoke)

gsort wholeid -_smk
bys wholeid: egen hxsmk = max(_smk)


**EtOH history
foreach v in preop_hx_etoh_use preop_hx_etoh_abuse post_alc {
	replace `v'=. if `v'==2
}

egen _etoh = rowmax(preop_hx_etoh_use preop_hx_etoh_abuse post_alc)

gsort wholeid -_etoh
bys wholeid: egen hxetoh = max(_etoh)

**Substance history
foreach v in preop_hx_substance_abuse { 
	replace `v'=. if `v'==2
}

egen _substance = rowmax(preop_hx_substance_abuse)

gsort wholeid -_substance
bys wholeid: egen hxsubstance = max(_substance)

keep wholeid hxetoh hxsmk hxsubstance
duplicates drop
merge 1:1 wholeid using whole_demo, nogen keep(using match)
save whole_demo, replace

**# geocoding
**download UWisc ADI 2020
clear all
import delimited "US_2020_ADI_Census Block Group_v3.2.csv", clear 
format fips %12.0f
destring adi_natrank, gen(adi_natrank_int) force
keep fips adi_natrank_int
save adi_uwisc, replace


**Convert WHOLE address to GEOID(aka FIPS) to match with UWisc ADI using FIPS
clear all
use whole_crude, clear

keep wholeid street city state zip
drop if mi(street) & mi(city) & mi(state) & mi(zip)
replace street=strproper(street)
replace city=strproper(city)
replace state=strupper(state)
	replace state=trim(state)
	replace state="FL" if strmatch(state, "FLORIDA")
	replace state="MD" if strmatch(state, "BALTIMORE")
	drop if strmatch(state,"BRTISH COLUMBIA")
	replace state="CA" if strmatch(state, "CALIFORNIA")
	replace state="CO" if strmatch(state, "COLORADO")
	replace state="CT" if strmatch(state, "CONNECTICUT")
	replace state="DC" if strmatch(state, "D.C")
	replace state="DC" if strmatch(state, "D.C.")
	replace state="DE" if strmatch(state, "DELAWARE")
	replace state="DC" if strmatch(state, "DISTRICT OF COLUMBIA")
	drop if strmatch(state,"DOHA")
	replace state="GA" if strmatch(state, "GEORGIA")
	replace state="IL" if strmatch(state, "ILLINOIS")
	replace state="IN" if strmatch(state, "INDIANA")
	replace state="ME" if strmatch(state, "MAINE")
	replace state="MD" if strmatch(state, "MARYLAND")
	replace state="MD" if wholeid=="GX385"
	replace state="MI" if strmatch(state, "MICHIGAN")
	replace state="NY" if strmatch(state, "NEW YORK")
	replace state="NC" if strmatch(state, "NORTH CAROLINA")
	replace state="OH" if strmatch(state, "OHIO")
	replace state="OR" if strmatch(state, "OREGON")
	replace state="PA" if strmatch(state, "PENNSYLVANIA")
	replace state="SC" if strmatch(state, "SOUTH CAROLINA")
	replace state="TX" if strmatch(state, "TEXAS")
	replace state="UT" if strmatch(state, "UTAH")
	replace state="VA" if strmatch(state, "VIRGINA") | strmatch(state, "VIRGINIA")
	replace state="WA" if strmatch(state, "WASHINGTON")
	replace state="DC" if strmatch(state, "WASHINGTON DC") | strmatch(state, "WASHINGTON  DC")
	drop if strmatch(state,"WEST COAST")
	replace state="WI" if strmatch(state, "WISCONSIN")
	
	
gsort wholeid
gen id = _n
save whole_census_address.dta, replace
export delimited id street city state zip using "whole_census_address.csv", novarnames replace //submit this to https://geocoding.geo.census.gov/geocoder/geographies/addressbatch?form

** import the geocode results from census (from url above)
clear all
import delimited "GeocodeResults.csv", clear 
rename v1 id
rename v2 address_whole
rename v3 match
rename v4 exact
rename v5 address_census
rename v6 coordinate
rename v7 id_tigerline
rename v8 id_tigerline_side
rename v9 statecode
rename v10 countycode
rename v11 tractcode
rename v12 blockcode

tostring statecode, gen(state) format(%02.0f)
tostring countycode, gen(county) format(%03.0f)
tostring tractcode, gen(tract) format(%06.0f)
tostring blockcode, gen(block) format(%04.0f)

egen fips_new = concat(state county tract block)
gen fips = substr(fips_new, 1, 12)
destring fips, replace force
format fips %12.0f
merge m:m fips using adi_uwisc, nogen keep(master match)
merge 1:1 id using "whole_census_address.dta", nogen keep(master match) keepusing(wholeid)

order wholeid adi_natrank_int fips fips_new
rename adi_natrank_int adi_natrank
count if strmatch(match, "No_Match") //n=363 with no match out of 3840
drop if strmatch(match, "No_Match")

lab var adi_natrank "Area Deprivation Index (ADI)"

save matched_adi, replace

**#Household Income
clear all
import delimited "ACSST5Y2021.S1901-Data.csv", varnames(1) clear 

keep geo_id name s1901_c01_012e //keeping only median household income
drop if geo_id=="Geography"

//change median income from string to integar
destring s1901_c01_012e, gen(hh_income) force

//harmonize geoid to fips for merging
//create census tract median household income
gen geoid = substr(geo_id, 10, 20)
destring geoid, gen(geoid_census) force
format geoid_census %11.0f
order geoid_census hh_income
save censustract_hhincome , replace

//use wholeid and match to the census
clear all
use matched_adi
keep wholeid state county tract block adi_natrank
egen geoid = concat(state county tract)
	gen censustract = substr(geoid, 1, 11)
	destring censustract, gen(geoid_census) force
	format geoid_census %11.0f
merge m:1 geoid_census using "censustract_hhincome.dta", nogen keep(master match) keepusing(hh_income)

qui twoway scatter hh_income adi_natrank
lab var hh_income "Household Income (matched by census tract)"

merge 1:1 wholeid using "whole_demo.dta", nogen keep(using match)
	drop state county tract block geoid censustract geoid_census
save whole_demo, replace

**# Post-donation cv and dm
clear all
use whole_crude_01.dta, clear

gen post_cv

gen post_htn

gen post_dm


**# LAB DATASET 1: CMP
clear all
use whole_crude_01
//RENAME VARIABLES
foreach v in bun co2 scr glu schloride spotassium sodium albumin {
	rename post_`v'* cmp_`v'*
}

rename cmp_co2_* cmp_cbdi*
rename cmp_schloride* cmp_scl*
rename cmp_spotassium* cmp_sk*
rename cmp_sodium* cmp_sna*
rename cmp_albumin* cmp_alb*


//SET NON-NUMERIC VALUES TO MISSING

foreach v of varlist cmp_bun* cmp_cbdi* cmp_scr* cmp_glu* cmp_scl* cmp_sk* cmp_sna* cmp_alb* {
	//macro equal to variable storage type
	local var_type: type `v'
	//if variable type is string, loop over and complete actions:
	if strpos("`var_type'", "str")==1 {
		replace `v' = "-999" if real(`v')==.
		destring `v', replace
		replace `v'=-999 if `v'==-999
	}
}


/*
//SET OUT OF RANGE VALUES TO MISSING
foreach v in cmp_bun {
	forvalues i=1/50 {
			replace `v'`i'=. if !inrange(`v'`i', 8, 20)
	}
}
*/


local append=0
forvalues i=6/11 { //loop applies to rdc_rows 6-11 (medical record abstraction events in REDCap)
		preserve
		keep if rdc_row==`i'
		keep wholeid cmp_date* cmp_bun* cmp_cbdi* cmp_scr* cmp_glu* ///
				cmp_scl* cmp_sk* cmp_sna* cmp_alb*
		drop cmp_alburia* 
		reshape long cmp_date cmp_bun cmp_cbdi cmp_scr cmp_glu ///
				cmp_scl cmp_sk cmp_sna cmp_alb, i(wholeid) j(labno)
		drop if mi(cmp_bun)&mi(cmp_cbdi)&mi(cmp_scr)&mi(cmp_glu)&mi(cmp_scl)&mi(cmp_sk)&mi(cmp_sna)&mi(cmp_alb) //don't know if there's a better way to code this
		if `append'==1 {
			append using whole_cmp.dta
			duplicates drop 
		}
		gsort wholeid cmp_date
		format cmp_date %td
		save whole_cmp.dta, replace
		export delimited using "whole_cmp.csv", replace
		restore
		local append=1
}


**# LAB DATASET 2: CBC
//RENAME VARIABLES
rename cbc_plat* cbc_plt*

//SET NON-NUMERIC VALUES TO MISSING
foreach v of varlist cbc_plt* cbc_hgb* {
	//macro equal to variable storage type
	local var_type: type `v'
	//if variable type is string, loop over and complete actions:
	if strpos("`var_type'", "str")==1 {
		replace `v' = "-999" if real(`v')==.
		destring `v', replace
		replace `v'=-999 if `v'==-999
	}
}

/*
//SET OUT OF RANGE VALUES TO MISSING
foreach v in cmp_bun {
	forvalues i=1/50 {
			replace `v'`i'=. if !inrange(`v'`i', 8, 20)
	}
}

*/


local append=0
forvalues i=6/11 { //loop applies to rdc_rows 6-11 (medical record abstraction events in REDCap)
		preserve
		keep if rdc_row==`i'
		keep wholeid cbc_date* cbc_plt* cbc_hgb* cbc_rbc* cbc_wbc*
		reshape long cbc_date cbc_plt cbc_hgb cbc_rbc cbc_wbc, i(wholeid) j(labno)
		drop if mi(cbc_plt)&mi(cbc_hgb)&mi(cbc_rbc)&mi(cbc_wbc)
		if `append'==1 {
			append using whole_cbc.dta
			duplicates drop 
		}
		gsort wholeid cbc_date
		format cbc_date %td
		save whole_cbc.dta, replace
		export delimited using "whole_cbc.csv", replace
		restore
		local append=1
}



**# LAB DATASET 3: VITAL SIGNS
**20220512 Chang wrote
//RENAME VARIABLES
foreach l in vital {
	foreach v in date sys dia hr cm in lb kg bmi {
		forvalues i=1/100 {
			rename `l'_`v'`i' vs_`v'`i'
		}
	}
}

rename vs_sys* vs_sbp*
rename vs_dia* vs_dbp*
rename vs_cm* vs_htcm*
rename vs_in* vs_htin*
rename vs_lb* vs_wtlb*
rename vs_kg* vs_wtkg*

//SET NON-NUMERIC VALUES TO MISSING
foreach v of varlist vs_sbp* vs_dbp* vs_hr* vs_htcm* vs_htin* vs_wtlb* vs_wtkg* vs_bmi* {
	//macro equal to variable storage type
	local var_type: type `v'
	//if variable type is string, loop over and complete actions:
	if strpos("`var_type'", "str")==1 {
		replace `v' = "-999" if real(`v')==.
		destring `v', replace
		replace `v'=-999 if `v'==-999
	}
}

local append=0
forvalues i=6/11 { //loop applies to rdc_rows 6-11 (medical record abstraction events in REDCap)
		preserve
		keep if rdc_row==`i'
		keep wholeid vs_date* vs_sbp* vs_dbp* vs_hr* vs_htcm* ///
						vs_htin* vs_wtlb* vs_wtkg* vs_bmi*
		reshape long vs_date vs_sbp vs_dbp vs_hr vs_htcm ///
						vs_htin vs_wtlb vs_wtkg vs_bmi, i(wholeid) j(labno)
		drop if mi(vs_sbp) & mi(vs_dbp) & mi(vs_hr) & mi(vs_htcm) ///
						& mi(vs_htin) & mi(vs_wtlb) & mi(vs_wtkg) & mi(vs_bmi)
		if `append'==1 {
			append using whole_vs.dta
			duplicates drop 
		}
		gsort wholeid vs_date
		format vs_date %td
		
		replace vs_htcm= vs_htin*2.54 if mi(vs_htcm) & !mi(vs_htin)
		replace vs_wtkg= vs_wtlb/2.205 if mi(vs_wtkg) & !mi(vs_wtlb)
		replace vs_bmi = vs_wtkg/((vs_htcm/100)^2) if mi(vs_bmi)
		
		save bgwhole_vs.dta, replace
		export delimited using "whole_vs.csv", replace
		restore
		local append=1
}

**# LAB DATASET 4: LIPIDS

//RENAME VARIABLES
rename lip_chol* lip_tc*
rename lip_trig* lip_tg*

//SET NON-NUMERIC VALUES TO MISSING

foreach v of varlist lip_tc* lip_hdl* lip_ldl* lip_vldl* lip_tg* {
	//macro equal to variable storage type
	local var_type: type `v'
	//if variable type is string, loop over and complete actions:
	if strpos("`var_type'", "str")==1 {
		replace `v' = "-999" if real(`v')==.
		destring `v', replace
		replace `v'=-999 if `v'==-999
	}
}

local append=0
forvalues i=6/11 { //loop applies to rdc_rows 6-11 (medical record abstraction events in REDCap)
		preserve
		keep if rdc_row==`i'
		keep wholeid lip_date* lip_tc* lip_hdl* lip_ldl* lip_vldl* lip_tg* 
		reshape long lip_date lip_tc lip_hdl lip_ldl lip_vldl lip_tg, i(wholeid) j(labno)
		drop if mi(lip_tc) & mi(lip_hdl) & mi(lip_ldl) & mi(lip_vldl) & mi(lip_tg) 
		if `append'==1 {
			append using whole_lip.dta
			duplicates drop 
		}
		gsort wholeid lip_date
		format lip_date %td
		save whole_lip.dta, replace
		export delimited using "whole_lip.csv", replace
		restore
		local append=1
}


**# LAB DATASET 5: UA URINALYSIS

//RENAME VARIABLES
rename ua_prot* ua_up*
rename ua_leukest* ua_lke*

//SET NON-NUMERIC VALUES TO MISSING

foreach v of varlist ua_up* ua_glu* ua_hgb* ua_wbc* ua_rbc* ua_lke* ua_nit* {
	//macro equal to variable storage type
	local var_type: type `v'
	//if variable type is string, loop over and complete actions:
	if strpos("`var_type'", "str")==1 {
		replace `v' = "-999" if real(`v')==.
		destring `v', replace
		replace `v'=-999 if `v'==-999
	}
}

local append=0
forvalues i=6/11 { //loop applies to rdc_rows 6-11 (medical record abstraction events in REDCap)
		preserve
		keep if rdc_row==`i'
		keep wholeid ua_date* ua_up* ua_glu* ua_hgb* ua_wbc* ///
					ua_rbc* ua_lke* ua_nit*
		reshape long ua_date ua_up ua_glu ua_hgb ua_wbc ///
					ua_rbc ua_lke ua_nit, i(wholeid) j(labno)
		drop if mi(ua_up) & mi(ua_glu) & mi(ua_hgb) & mi(ua_wbc) ///
					& mi(ua_rbc) & mi(ua_lke) & mi(ua_nit)
		if `append'==1 {
			append using whole_ua.dta
			duplicates drop 
		}
		gsort wholeid ua_date
		format ua_date %td
		save whole_ua.dta, replace
		export delimited using "whole_ua.csv", replace
		restore
		local append=1
}


**# LAB DATASET 4: URM URINE VALUES

//RENAME VARIABLES
rename urm_spotprot* urm_sp*
rename urm_spotcre* urm_cr*
rename urm_totprot* urm_24tp*
rename urm_totcre* urm_24cr*

//SET NON-NUMERIC VALUES TO MISSING

foreach v of varlist urm_sp* urm_cr* urm_24tp* urm_24cr* urm_crcl* {
	//macro equal to variable storage type
	local var_type: type `v'
	//if variable type is string, loop over and complete actions:
	if strpos("`var_type'", "str")==1 {
		replace `v' = "-999" if real(`v')==.
		destring `v', replace
		replace `v'=-999 if `v'==-999
	}
}

local append=0
forvalues i=6/11 { //loop applies to rdc_rows 6-11 (medical record abstraction events in REDCap)
		preserve
		keep if rdc_row==`i'
		keep wholeid urm_date* urm_sp* urm_cr* urm_24tp* urm_24cr* urm_crcl*
		reshape long urm_date urm_sp urm_cr urm_24tp urm_24cr urm_crcl ///
					, i(wholeid) j(labno)
		drop if mi(urm_sp) & mi(urm_cr) & mi(urm_24tp) & mi(urm_24cr) & mi(urm_crcl) 
		if `append'==1 {
			append using whole_urm.dta
			duplicates drop 
		}
		gsort wholeid urm_date
		format urm_date %td
		save whole_urm.dta, replace
		export delimited using "whole_urm.csv", replace
		restore
		local append=1
}





**#Eligible and tried to contact
**inherently if someone did a survey it was successful contact, regardless of what the status box states
clear all
use ${DT}whole_crude_01.dta, clear

egen done_survey = rownonmiss(s1_date sf_date)
gsort wholeid -done_survey
by wholeid: gen any_survey=done_survey[1]
keep wholeid any_survey
duplicates drop

tempfile any_survey
save `any_survey', replace

**organize data
clear all
use ${DT}whole_crude_01.dta, clear
keep if strmatch(redcap_event_name, "data_import*")

**add indicator that any survey was done
merge m:1 wholeid using `any_survey', nogen keep(master match)

**CLEAN UP SOURCE POPULATION
unique wholeid //n=7340
drop if mi(tx_dt) & mi(tx_year) //no date or year of donation at all (n=32)
drop if tx_dt>td(01may2020) & !mi(tx_dt) //not eligible if transplanted <2 years (n=16)
drop if mi(tx_center) | tx_center=="OTHER" //missing tx center or donor from another institution that donated to a recipient at one of the WHOLE participating institution
drop if inlist(survey_consent, 6, 7) //non-donor and not yet 2 years post donation (n=52)
drop if any_survey!=1 & ( mi(tx_center_contactinfo) & mi(mr_consent_notes) ) //never had survey AND had no contact info at all in REDCap boxes titled contact information & whole participant status
unique wholeid //n=7172

**FLOW CHART NUMBERS
unique wholeid if survey_consent==5 //international or non-english

recode alive (2=0)
replace alive=0 if wholeid=="FK595"  | wholeid=="LV564"  | wholeid=="TK636" 
replace alive=0 if !mi(death_date) | !mi(death_date_possible)
replace alive=0 if any_survey!=1 & survey_consent==4 & ((strmatch(mr_consent_notes, "*decease*")) | (strmatch(mr_consent_notes, "*passed*")) | (strmatch(mr_consent_notes, "*dead*")) | (strmatch(tx_center_contactinfo, "*decease*")) | (strmatch(tx_center_contactinfo, "*passed*")) | (strmatch(tx_center_contactinfo, "*dead*"))) // n=98

tab alive any_survey,m // n=173 confirmed deceased AND no surveys ever done

drop if alive==0 & any_survey==0 //confirmed deceased AND no surveys ever done
drop if survey_consent==5 //international or non-english

keep wholeid alive
duplicates drop
gen eligible=1
unique wholeid

save ${DT}eligible.dta, replace

