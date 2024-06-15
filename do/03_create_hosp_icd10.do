capture log close _all
capture cmdlog close
clear all 

cd "S:\whole\01_Hospitalization"
global tdate: di %tdCCYYNNDD date(c(current_date),"DMY") 
global cdat: di %tdCCYYNNDD date(c(current_date),"DMY") 
log using "log_03_hosp_${cdat}.log",  replace

**# ICD10 Excel (Fall 2022)
*import the icd10 codes from xlsx to stata
**manually assigned ICD-10 codes to each hospitalization
clear all
import excel hospcauses_icd10.xlsx, sheet("Hosp-ER") firstrow case(lower) clear
drop a
drop hosp_or_er_num
rename ldfuid wholeid
rename hosp_or_er_date hosper_yr
compress hosp_or_er_cause_original
	format hosp_or_er_cause_original %20s
	replace hosp_or_er_cause_original=strtrim(hosp_or_er_cause_original)
compress hosp_or_er_cause_editted
	format hosp_or_er_cause_editted %20s
compress notes
	format notes %20s
duplicates drop

*decided later that heart catheterization should be s_cardiac and not just I99
replace code="s_cardiac" if code=="I99"
save whole_hosp_icd10, replace



**# REDCap (Spring 2023)
//originally exported the hospitalization causes and assigned ICD-10 codes manually
//then lost that export code, so rewrote the code and found some hospitalizations that did not have assigned ICD-10's, which is why the code below exists
clear all
use whole_crude_01, clear
order wholeid redcap_event_name rdc_row
keep if inrange(rdc_row, 1, 5)
keep wholeid rdc_row s1_date sf_date s*_hos*

replace s1_hospitalization=. if inlist(s1_hospitalization, 2, 3) //2=dont know; 3=decline to answer
replace sf_hospitalization=. if inlist(sf_hospitalization, 2, 3)

egen temp_hosp_bin = rowmax(s*_hospitalization)
gsort wholeid -temp_hosp_bin
by wholeid: gen hosp_bin=temp_hosp_bin[1]
	lab var hosp_bin "Hospitalization since donation ever: yes/no"
	
egen temp_hosp_count = rowmax(s*_hospitalizationcount)
gsort wholeid -temp_hosp_count
by wholeid: gen hosp_count=temp_hosp_count[1]
	lab var hosp_count "Max count of hospitalization since donation"

merge m:1 wholeid using "whole_demo", nogen keep(master match) keepusing(tx_dt tx_yr)

//remove hospitalization years that were reported before the year of donation
tostring s1_hospcause*, replace force
rename sf_hospicause25 sf_hospcause25
tostring sf_hospcause*, replace force
foreach n of numlist 1/25 {
replace s1_hospyr`n'=. if s1_hospyr`n'<tx_yr
replace s1_hospcause`n'="" if s1_hospyr`n'<tx_yr
replace sf_hospyr`n'=. if sf_hospyr`n'<tx_yr
replace sf_hospcause`n'="" if sf_hospyr`n'<tx_yr
}

	
egen temp_firsthosp_yr = rowmin(s*_hospyr*)
gsort wholeid temp_firsthosp_yr
by wholeid: gen firsthosp_yr=temp_firsthosp_yr[1]
	lab var firsthosp_yr "Years between donation and first hospitalization"

	
preserve
	drop if mi(hosp_bin) & mi(hosp_count)
		egen survey_date=rowmax (s*_date)
		gsort wholeid -hosp_bin -survey_date
		by wholeid: gen s_date=survey_date[1]
	keep wholeid hosp_bin hosp_count firsthosp_yr s_date
	merge m:1 wholeid using "whole_demo", nogen keep(master match) keepusing(tx_dt tx_yr)
	replace s_date= (s_date-tx_dt)/365.25 if !mi(tx_dt)
		replace s_date= year(s_date)-tx_yr if mi(tx_dt) & !mi(tx_yr)
		lab var s_date "Years between donation and last survey"
	duplicates drop
	isid wholeid
	save hosp_bin, replace
restore

foreach n of numlist 1/7 {
	replace sf_hospyr`n'=s1_hospyr`n' if rdc_row==1
	replace sf_hospcause`n'=s1_hospcause`n'	if rdc_row==1
}

keep wholeid sf_hospyr* sf_hospcause* hosp_bin hosp_count

egen tag = rownonmiss(sf_hospyr1 sf_hospcause1 sf_hospyr2 sf_hospcause2 sf_hospyr3 sf_hospcause3 sf_hospyr4 sf_hospcause4 sf_hospyr5 sf_hospcause5 sf_hospyr6 sf_hospcause6 sf_hospyr7 sf_hospcause7 sf_hospyr8 sf_hospcause8 sf_hospyr9 sf_hospcause9 sf_hospyr10 sf_hospcause10 sf_hospyr11 sf_hospcause11 sf_hospyr12 sf_hospcause12 sf_hospyr13 sf_hospcause13 sf_hospyr14 sf_hospcause14 sf_hospyr15 sf_hospcause15 sf_hospyr16 sf_hospcause16 sf_hospyr17 sf_hospcause17 sf_hospyr18 sf_hospcause18), strok
drop if mi(hosp_bin) & tag==0
duplicates drop
duplicates tag wholeid, gen(dup)
drop if dup>0 & tag==0

drop tag dup
gsort wholeid sf_hospyr1
bys wholeid: gen seq=_n

tostring sf_hospcause*, replace
tab seq
forvalues i=1/4 { 
	preserve
		keep if seq==`i'
		reshape long sf_hospyr sf_hospcause, i(wholeid) j(num) string
		drop if mi(sf_hospyr) & mi(sf_hospcause)
		save temp_hosp_`i', replace
	restore
}

clear all
use temp_hosp_1, clear
append using temp_hosp_2
append using temp_hosp_3
append using temp_hosp_4
drop num seq hosp_bin hosp_count

rename sf_hospcause hosp_or_er_cause_original
rename sf_hospyr hosper_yr
gen hosp_or_er="hosp"

duplicates drop


export excel using "hospcauses_icd10_crude.xls", sheetreplace firstrow(variables)

**confirm that it's the same
gen new=1
compress hosp_or_er_cause_original
	recast str413 hosp_or_er_cause_original
	format hosp_or_er_cause_original %20s
	replace hosp_or_er_cause_original=strtrim(hosp_or_er_cause_original)
merge m:m wholeid hosp_or_er_cause_original hosper_yr using "whole_hosp_icd10.dta", keep(master match) 
	tab _merge // about 131
	//bro if _merge==1 & mi(code)

**#ICD-10 Editing (Merge Excel and REDCap dataset and code the remaining ICD-10)
replace hosp_or_er_cause_original=strlower(hosp_or_er_cause_original)
replace code="" if code=="."
replace code=subinstr(code," ","",.)
replace code=subinstr(code,"  ","",.)

replace code="s_*" if ///
	strmatch(hosp_or_er_cause_original, "removal of non-malignant growth") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "stent") & mi(code)


replace code="s_hernia" if ///
	strmatch(hosp_or_er_cause_original, "removal of hernia") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "hernia repair (3+)") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "incisional hernia repair from donation") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "herena from kidney surgery") & mi(code) 

replace code="hernia" if ///
	strmatch(hosp_or_er_cause_original, "hernia") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "hernia") | ///
	strmatch(hosp_or_er_cause_original, "hiatal hernia surgery") | ///
	strmatch(hosp_or_er_cause_original, "1st incisional hernia") | ///
	strmatch(hosp_or_er_cause_original, "2nd incisional hernia") | ///
	strmatch(hosp_or_er_cause_original, "hiatal hernia surgery") | ///
	strmatch(hosp_or_er_cause_original, "incision hernia") | ///
	strmatch(hosp_or_er_cause_original, "incisional hernia") | ///
	strmatch(hosp_or_er_cause_original, "umbilical hernia") | ///
	strmatch(hosp_or_er_cause_original, "incarcerated inguinal hernia (passed out - fell and fractured my back)") 
	
replace code="s_spine" if ///
	strmatch(hosp_or_er_cause_original, "*back surg**") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "*spine surgery*") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "lower back surgeries") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "second surgery on same herniated disc")

replace code="s_ob" if ///
	strmatch(hosp_or_er_cause_original, "childbirth") | ///
	strmatch(hosp_or_er_cause_original, "child birth")
	
replace code="s_gyn" if ///
	strmatch(hosp_or_er_cause_original, "*child*") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "uterine cancer surgery") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "hysterectomy") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "hysterectomy with salpingo-oophorectomy") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "myomectomy") | ///
	strmatch(hosp_or_er_cause_original, "myomectomy surgery")
	
replace code="s_uro" if ///
	strmatch(hosp_or_er_cause_original, "prostate surgery") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "enlarged prostrate surgery") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "hydocelectomy")

replace code="s_opht" if ///
	strmatch(hosp_or_er_cause_original, "cataracts removed") & mi(code)
	
replace code="s_ortho" if ///
	strmatch(hosp_or_er_cause_original, "*knee surgery*") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "carpal tunnel surgery") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "thumb surgery") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "shoulder surgery") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "*fracture*") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "acl repair") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "hip replacement") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "*knee replacement*") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "rotator cuff*") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "broken arm dislocation") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "ppt had two knees replaced") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "messed up plate they put in and got new hip") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "revition l/s hip") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "shoulder replacement") & mi(code) 
	
replace code="s_gi" if ///
	strmatch(hosp_or_er_cause_original, "gallbladder surgery") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "gallbladder removed") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "removed appendix") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "removal of stone in cbd") & mi(code) 
	
replace code="s_cardiac" if ///
	strmatch(hosp_or_er_cause_original, "*open heart surgery (septal myectomy)*") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "* open heart surgerym*") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "heart by-pass") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "heart cath*") & mi(code) 

replace code="s_ent" if ///
	strmatch(hosp_or_er_cause_original, "jaw surgery") & mi(code)
	
replace code="s_onc" if ///
	strmatch(hosp_or_er_cause_original, "*melanom*") | ///
	strmatch(hosp_or_er_cause_original, "cancer removal") | ///
	strmatch(hosp_or_er_cause_original, "fatty tumors removed 2x")
	
replace code="K57" if ///
	strmatch(hosp_or_er_cause_original, "*diverticuliti*") & mi(code)

replace code="K56.5" if ///
	strmatch(hosp_or_er_cause_original, "blood vessels being choked from scar tissue from donation") & mi(code)

replace code="K63.1" if ///
	strmatch(hosp_or_er_cause_original, "ppt had a perforated duodenum") & mi(code)
	
replace code="K63.5" if ///
	strmatch(hosp_or_er_cause_original, "polyp removed from colon") & mi(code)

replace code="K64.9" if ///
	strmatch(hosp_or_er_cause_original, "hemorriods") & mi(code)
	
replace code="K85" if ///
	strmatch(hosp_or_er_cause_original, "pancreatitis") & mi(code)
	
replace code="I82.409" if ///
	strmatch(hosp_or_er_cause_original, "blood clot in leg") & mi(code)

replace code="I82" if ///
	strmatch(hosp_or_er_cause_original, "blood clot") & mi(code)
	
replace code="K82.9" if ///
	strmatch(hosp_or_er_cause_original, "gallbladder*") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "*gall bladder*") & mi(code)
	
replace code="R07.9" if ///
	strmatch(hosp_or_er_cause_original, "*chest pain*") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "heart attack symptoms") & mi(code)
	
replace code="I50" if ///
	strmatch(hosp_or_er_cause_original, "heart failure") & mi(code) 

replace code="R03" if ///
	strmatch(hosp_or_er_cause_original, "high blood pressure") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "blood pressure") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "blood presure") & mi(code)
	
replace code="E86.0" if ///
	strmatch(hosp_or_er_cause_original, "dehydration") & mi(code)
	
replace code="I63.9" if ///
	strmatch(hosp_or_er_cause_original, "stroke") & mi(code)  | ///
	strmatch(hosp_or_er_cause_original, "seveal clotting problems on brain") & mi(code)

replace code="J09" if ///
	strmatch(hosp_or_er_cause_original, "influenza") & mi(code)
	
replace code="J18.9" if ///
	strmatch(hosp_or_er_cause_original, "pneumonia") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "namonia") & mi(code)

replace code="J09" if ///
	strmatch(hosp_or_er_cause_original, "flu") & mi(code)
	
replace code="N20" if ///
	strmatch(hosp_or_er_cause_original, "kidney stone") & mi(code) 

replace code="N32" if ///
	strmatch(hosp_or_er_cause_original, "bladder sling") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "ppt had a bladder sling") & mi(code)

replace code="N43.3" if ///
	strmatch(hosp_or_er_cause_original, "hydocele") & mi(code) 

replace code="N81" if ///
	strmatch(hosp_or_er_cause_original, "prolapsed bladder") & mi(code) 
	
replace code="J44.9" if ///
	strmatch(hosp_or_er_cause_original, "copd") & mi(code) 
	
replace code="R17" if ///
	strmatch(hosp_or_er_cause_original, "yellow jaundice") & mi(code) 

replace code="O94" if ///
	strmatch(hosp_or_er_cause_original, "pregnancy") & mi(code) 
	
replace code="G43" if ///
	strmatch(hosp_or_er_cause_original, "migraine") & mi(code)

replace code="H81" if ///
	strmatch(hosp_or_er_cause_original, "vertigo") & mi(code) 

replace code="G03.9" if ///
	strmatch(hosp_or_er_cause_original, "meningitis") & mi(code) 

replace code="G65" if ///
	strmatch(hosp_or_er_cause_original, "guillain barre in remission") & mi(code) 
	
replace code="D51.0" if ///
	strmatch(hosp_or_er_cause_original, "anemia") & mi(code)

replace code="D28.9" if ///
	strmatch(hosp_or_er_cause_original, "uterine cancer") & mi(code)
	
replace code="E21.5" if ///
	strmatch(hosp_or_er_cause_original, "parathyroid") & mi(code)

replace code="E87" if ///
	strmatch(hosp_or_er_cause_original, "electrolytes were out") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "loss of potasium") & mi(code)
	
replace code="H54.7" if ///
	strmatch(hosp_or_er_cause_original, "blind in left eye") & mi(code)

replace code="M20.41" if ///
	strmatch(hosp_or_er_cause_original, "right foot second toe hammered") & mi(code)

replace code="M54.3" if ///
	strmatch(hosp_or_er_cause_original, "bursistis and sciatica pain") & mi(code)
	
replace code="I89" if ///
	strmatch(hosp_or_er_cause_original, "lymphaticovenular anastamosis") & mi(code)

replace code="R06.02" if ///
	strmatch(hosp_or_er_cause_original, "dimer test") & mi(code)

replace code="S72" if ///
	strmatch(hosp_or_er_cause_original, "broken hip") & mi(code)
	
replace code="S61" if ///
	strmatch(hosp_or_er_cause_original, "finger injury") & mi(code)
	
replace code="S34" if ///
	strmatch(hosp_or_er_cause_original, "back injury (bulging disc)") & mi(code)

	
replace code="T81" if ///
	strmatch(hosp_or_er_cause_original, "infected mesh (1x)") & mi(code)

	
replace code="V43" if ///
	strmatch(hosp_or_er_cause_original, "car accident") & mi(code)

	
replace code="W19" if ///
	strmatch(hosp_or_er_cause_original, "fell off a ladder") & mi(code)
	
replace code="R57.9" if ///
	strmatch(hosp_or_er_cause_original, "laser damaged organs  septic shock")
	
replace code="B99" if ///
	strmatch(hosp_or_er_cause_original, "infection") & mi(code) | ///
	strmatch(hosp_or_er_cause_original, "infection in left leg") & mi(code)
	
replace code="other" if ///
	strmatch( hosp_or_er_cause_original, "body was in shock and wasnt able to eat after the transplant") | ///
	strmatch( hosp_or_er_cause_original, "stock 10/2015 due to surgery 9/2015...treated by dr. rafael llinas at hopkins (bayview - 410-550-1042); released 3/2016 with yearly checkup") | ///
	strmatch( hosp_or_er_cause_original, "same reason as above") 

	
**adding records with multiple admission reasons
set obs `=_N+6'

replace wholeid="GC454" in 2081
replace hosp_or_er_cause_original="cancer" in 2081
replace notes="cancer" in 2081
replace code="D49" in 2081

replace wholeid="SB455" in 2082
replace hosp_or_er_cause_original="bil tks" in 2082
replace code="s_ortho" in 2082

replace wholeid="SZ468" in 2083
replace hosp_or_er_cause_original="gallbladder removed. umbilical hernia repaired." in 2083
replace code="s_hernia" in 2083

replace wholeid="EH923" in 2084
replace hosp_or_er_cause_original="intestinal blockage; mesentary hernia repair" in 2084
replace code="s_hernia" in 2084

replace wholeid="GV464" in 2085
replace hosp_or_er_cause_original="appendicitis and hernia" in 2085
replace code="hernia" in 2085

replace wholeid="BT979" in 2086
replace hosp_or_er_cause_original="scar tissue, prostate removal, small bowel blockage" in 2086
replace code="s_uro" in 2086

*clean it up
drop _merge

save whole_hosp_icd10_master, replace

**#Assign ICD-10
//organize the cause for hospitalization by system according to ICD-10
clear all
use whole_hosp_icd10_master, clear

merge m:1 wholeid using "whole_demo.dta", keep(master match) keepusing(tx_dt tx_yr tx_age) nogen
replace hosper_yr = . if hosper_yr<1900 | hosper_yr>2022
	
**remove duplicate hospitalizations and code
keep wholeid code shock hosp_or_er_cause_original 
duplicates drop

//drop causes that are weird
drop if hosp_or_er_cause_original=="n"

//clean up the codes
replace code="s_ortho" if code=="s_wrist"
replace code="s_*" if code=="s_?"
codebook code //294 unique codes

tab code if strmatch(code, "s_*"), sort

gen hosp_surg_any = strmatch(code, "s_*")
gen hosp_surg_ortho = strmatch(code, "s_ortho") 
gen hosp_surg_gi = strmatch(code, "s_gi") 
gen hosp_surg_gyn = strmatch(code, "s_gyn") 
gen hosp_surg_ob_birth = strmatch(code, "s_ob") //delivery or c section
gen hosp_surg_breast = strmatch(code, "s_breast") 

gen hosp_surg_other = strmatch(code, "*s_*") & ///
hosp_surg_ortho!=1 & ///
hosp_surg_gi!=1 & ///
hosp_surg_gyn!=1 & ///
hosp_surg_ob_birth!=1 & ///
hosp_surg_breast!=1  ///any surgery other than the top 5

gen hosp_hernia = strmatch(code, "s_hernia") | strmatch(code, "hernia")

gen hosp_inf = strmatch(code, "A*") | strmatch(code,"B*") //PNA, MRSA, flu

gen hosp_neo = 0 //cancer
replace hosp_neo = strmatch(code, "C*") | strmatch(code, "s_cancer") | strmatch(code, "s_onc")
forvalues n=0/9 {
	replace hosp_neo = 1 if strmatch(code, "D0`n'*")
}
forvalues n=10/49 {
	replace hosp_neo = 1 if strmatch(code, "D`n'*")
}

gen hosp_heme = 0 //blood, spleen, 
forvalues n=50/89 {
	replace hosp_heme = 1 if strmatch(code, "D`n'*")
}

gen hosp_endo = strmatch(code, "E*") | strmatch(code,"s_endo")  
	replace hosp_endo=0 if strmatch(code, "E86.0") //volume depletion categorized as cv b/c
	
gen hosp_psych = strmatch(code, "F*")  
forvalues n=40/46 {
	replace hosp_psych = 1 if strmatch(code, "R`n'*")
}

gen hosp_neuro = strmatch(code, "G*") | strmatch(code,"s_neuro") | strmatch(code,"s_spine") | strmatch(code,"s_back") 
replace hosp_neuro = 1 if strmatch(code, "R20*") //disturbance of skin sensation
forvalues n=25/29 { //numbness
	replace hosp_neuro = 1 if strmatch(code, "R`n'*")
}
forvalues n=47/49 { //speech
	replace hosp_neuro = 1 if strmatch(code, "R`n'*")
}
replace hosp_neuro = 1 if strmatch(code, "R51*") | strmatch(code, "R55*") | strmatch(code, "R56*")

gen hosp_ent = strmatch(code, "H*") | strmatch(code,"s_ent") 

gen hosp_cv = strmatch(code, "I*") | strmatch(code,"s_card*") | strmatch(code,"s_CT") | strmatch(code, "s_vasc") //PE, MI
forvalues n=0/9 {
	replace hosp_cv = 1 if strmatch(code, "R0`n'*")
}
replace hosp_cv = 1 if strmatch(code, "R57*") //shock
replace hosp_cv = 1 if shock ==1
replace hosp_cv = 1 if strmatch(code, "E86*") //volume depletion

gen hosp_resp = strmatch(code, "J*") | strmatch(code,"s_lung*") //PE, MI

gen hosp_gi = strmatch(code, "K*") | strmatch(code,"s_gi") //appendicitis, torsion, rectal bleeding
forvalues n=10/19 {
	replace hosp_gi = 1 if strmatch(code, "R`n'*")
}

gen hosp_derm = strmatch(code, "L*") | strmatch(code,"s_skin") 
forvalues n=21/23 {
	replace hosp_derm = 1 if strmatch(code, "R`n'*")
}

gen hosp_msk = strmatch(code, "M*") | strmatch(code,"s_ortho") 
forvalues n=40/99 { 
	replace hosp_msk = 1 if strmatch(code, "S`n'*")
}

gen hosp_renal = strmatch(code,"s_uro") //urologic-renal, exclude female or male systems
replace hosp_renal = 1 if strmatch(code, "N99*") //Intraoperative and postprocedural complications and disorders of genitourinary system, not elsewhere classified N99-
forvalues n=0/9 {
	replace hosp_renal = 1 if strmatch(code, "N0`n'*")
}
forvalues n=10/39 {
	replace hosp_renal = 1 if strmatch(code, "N`n'*")
}
forvalues n=30/35 { //hematuria, oliguria, anuria
	replace hosp_renal = 1 if strmatch(code, "R`n'*")
}
replace hosp_renal = 1 if strmatch(code, "R`94.4*") //abnormal creatinine
forvalues n=0/2 {
	replace hosp_renal = 1 if strmatch(code, "R8`n'*") //abnormal urine
}


gen hosp_uro_male = 0 //uro-male
forvalues n=40/53 {
	replace hosp_uro_male = 1 if strmatch(code, "N`n'*")
}
replace hosp_uro_male = 1 if strmatch(code, "R36*")

gen hosp_breast = strmatch(code,"s_breast")
forvalues n=60/65 {
	replace hosp_breast = 1 if strmatch(code, "N`n'*")
}

gen hosp_uro_female = strmatch(code,"s_gyn") | strmatch(code,"s_urogyn") //uro-female
forvalues n=70/98 {
	replace hosp_uro_female = 1 if strmatch(code, "N`n'*")
}

gen hosp_preg = 0
forvalues n=0/9 {
	replace hosp_preg = 1 if strmatch(code, "O0`n'*")
}
forvalues n=17/99 {
	replace hosp_preg = 1 if strmatch(code, "O`n'*")
}

gen hosp_ob_hemodynamics = 0
forvalues n=10/16 {
	replace hosp_ob_hemodynamics = 1 if strmatch(code, "O`n'*")
}

gen hosp_postop_comp = strmatch(code, "T81*") //postop complications, wound dehisence, infection

gen hosp_fall = strmatch(code, "W19*") //fall

//macro to group hospital code
global hosp_code hosp_surg_any hosp_surg_ortho hosp_surg_gi hosp_surg_gyn hosp_surg_ob_birth hosp_surg_breast hosp_surg_other hosp_inf hosp_neo hosp_heme hosp_endo hosp_psych hosp_neuro hosp_ent hosp_cv hosp_resp hosp_gi hosp_derm hosp_msk hosp_renal hosp_uro_male hosp_breast hosp_uro_female hosp_preg hosp_ob_hemodynamics hosp_postop_comp hosp_fall hosp_hernia

//with cause but code is anything other
egen temp = rowmax($hosp_code) 
gen hosp_other = inlist(temp,0) & !mi(code) //MVA (V43, T14), constitutional (R50), meckel's (Q43)
drop temp

**# Supplemental Fig 2 (For Alain)
if 1 {
	
preserve
merge m:1 wholeid using "hosp_final.dta", nogen keep(using match)
replace hosp_or_er_cause_original="" if hosp_or_er_cause_original=="."


unique wholeid if !mi(hosp_or_er_cause_original)

unique wholeid if !mi(code)

unique code if !mi(code)

count if !mi(hosp_or_er_cause_original) & !mi(code)

keep code shock hosp_or_er_cause_original hosp_surg_any hosp_surg_ortho hosp_surg_gi hosp_surg_gyn hosp_surg_ob_birth hosp_surg_breast hosp_surg_other hosp_inf hosp_neo hosp_heme hosp_endo hosp_psych hosp_neuro hosp_ent hosp_cv hosp_resp hosp_gi hosp_derm hosp_msk hosp_renal hosp_uro_male hosp_breast hosp_uro_female hosp_preg hosp_ob_hemodynamics hosp_postop_comp hosp_fall hosp_other hosp_hernia 

drop if mi(code) & mi(hosp_or_er_cause_original)

rename hosp_or_er_cause_original original
rename hosp_* *
duplicates drop code original, force
//export for Alain to create suppelemntary figure
export excel using "foralain_hospcause_S2 Figure.xlsx" , sheetreplace firstrow(variables)
restore
	
}



**# CV hospitalization, year to first hospitalization 
if 2 {
	
preserve

merge m:m wholeid hosp_or_er_cause_original using whole_hosp_icd10_master, nogen keep(master match) keepusing(hosper_yr)
keep wholeid hosp_cv hosper_yr
drop if hosp_cv==0
gsort wholeid hosper_yr
by wholeid: gen hosp_cv_yr = hosper_yr[1]
keep wholeid hosp_cv_yr
duplicates drop
merge 1:1 wholeid using whole_demo, nogen keep(master match) keepusing(tx_yr)
replace hosp_cv_yr= hosp_cv_yr-tx_yr
isid wholeid
save hosp_cv_yr, replace

restore
	
}

**# non-ob birth hospitalization
if 2 {
	
preserve

merge m:m wholeid hosp_or_er_cause_original using whole_hosp_icd10_master, nogen keep(master match) keepusing(hosper_yr)
drop if hosp_surg_ob_birth==1
duplicates drop
global hosp_code hosp_surg_any hosp_surg_ortho hosp_surg_gi hosp_surg_gyn hosp_surg_ob_birth hosp_surg_breast hosp_surg_other hosp_inf hosp_neo hosp_heme hosp_endo hosp_psych hosp_neuro hosp_ent hosp_cv hosp_resp hosp_gi hosp_derm hosp_msk hosp_renal hosp_uro_male hosp_breast hosp_uro_female hosp_preg hosp_ob_hemodynamics hosp_postop_comp hosp_fall hosp_hernia hosp_other

drop code
duplicates drop
collapse (sum) ${hosp_code}, by(wholeid)

foreach var in $hosp_code {
	replace `var'=1 if `var'>0 & !mi(`var')
}

drop if mi(wholeid)
isid wholeid
save hosp_icd10_noob, replace

**#create master hosp dataset
clear all
use hosp_bin, clear
merge 1:1 wholeid using "hosp_icd10_noob.dta", nogen keep(master match)

foreach var in $hosp_code {
	replace `var'=. if hosp_bin==0
}

merge 1:1 wholeid using "whole_demo.dta", nogen keep(master match)

replace firsthosp_yr= firsthosp_yr-tx_yr

save hosp_master_noob, replace

restore
	
}

global hosp_code hosp_surg_any hosp_surg_ortho hosp_surg_gi hosp_surg_gyn hosp_surg_ob_birth hosp_surg_breast hosp_surg_other hosp_inf hosp_neo hosp_heme hosp_endo hosp_psych hosp_neuro hosp_ent hosp_cv hosp_resp hosp_gi hosp_derm hosp_msk hosp_renal hosp_uro_male hosp_breast hosp_uro_female hosp_preg hosp_ob_hemodynamics hosp_postop_comp hosp_fall hosp_hernia hosp_other

drop code
duplicates drop
collapse (sum) ${hosp_code}, by(wholeid)

foreach var in $hosp_code {
	replace `var'=1 if `var'>0 & !mi(`var')
}

drop if mi(wholeid)
isid wholeid

save hosp_icd10, replace

**#create master hosp dataset
clear all
use hosp_bin, clear
merge 1:1 wholeid using "hosp_icd10.dta", nogen keep(master match)

foreach var in $hosp_code {
	replace `var'=. if hosp_bin==0
}

merge 1:1 wholeid using "whole_demo.dta", nogen keep(master match)

replace firsthosp_yr= firsthosp_yr-tx_yr

save hosp_master, replace
