capture log close _all
capture cmdlog close
clear all 

cd "S:\whole\01_Hospitalization"
global tdate: di %tdCCYYNNDD date(c(current_date),"DMY") 
global cdat: di %tdCCYYNNDD date(c(current_date),"DMY") 
log using "log_06_table_${cdat}.log",  replace

**# Manuscript numbers
clear all
use hosp_final.dta, clear
count 
gsort tx_dt 
list tx_dt in 1
gsort -tx_dt
list tx_dt in 1

sum s_date,d

sum adi_natrank,d


**# Manuscript ICD10
//post-donation hospitalization
clear all
use whole_hosp_icd10_master
merge m:1 wholeid using "hosp_final.dta", nogen keep(using match)
replace hosp_or_er_cause_original="" if hosp_or_er_cause_original=="."


unique wholeid if !mi(hosp_or_er_cause_original)

unique wholeid if !mi(code)

unique code if !mi(code)

count if !mi(hosp_or_er_cause_original) & !mi(code)


**# Table1 (demo)
clear all
use hosp_final.dta, clear


     global title: di ///
	    "Table 1: Demographic and health characteristic of live kidney donors at the time of nephrectomy. "
     global excelfile: di "Table1_LKD_Hosp"
     global byvar hosp_bin 
	 
     global contvars tx_age last_pretx_sbp last_pretx_dbp last_pretx_bmi ckdepi_pre hh_income adi_natrank s_date
     global binaryvars open female hxsmk pre_hx_dm pre_hx_htn insurance_pre college_bin
     global multivars race_howell tx_center edu_whole edu_srtr srtr_pre_insurance_type
	 
     global footnotes1 tx_age last_pretx_sbp last_pretx_dbp last_pretx_bmi ckdepi_pre hh_income adi_natrank
     global footnotes2 open female hxsmk pre_hx_dm pre_hx_htn insurance_pre college_bin
     global footnotes3 race_howell tx_center edu_whole edu_srtr srtr_pre_insurance_type
	 

     //command
     which table1_options
     table1_options, ///           
	 title("$title") ///  by($byvar) ///
		 cont($contvars) ///
		 binary($binaryvars) ///
		 multi($multivars)  ///
		 foot("$footnotes1 $footnotes2 $footnotes3") ///
		 excel("$excelfile") 
 
table1, ///
vars(open bin \ tx_age conts \ female bin \ race_howell cat \ hxsmk bin \ hh_income conts \ edu_whole cat \ adi_natrank conts \ adi_bin bin \ pre_hx_htn bin \ pre_hx_dm bin \ ckdepi_pre conts \  last_pretx_sbp conts \ last_pretx_dbp conts \ last_pretx_bmi conts \ insurance_pre bin \ srtr_pre_insurance_type cat \ tx_center cat) ///
onecol cformat(%3.0f) format(%3.0f) cmissing ///
saving(hosp_${cdat}, replace)

**#Table2 (cause of hosp)
clear all
use hosp_final.dta, clear
keep if hosp_bin==1

//macro to group hospital code
global hosp_code hosp_surg_any hosp_surg_ortho hosp_surg_gi hosp_surg_gyn hosp_surg_ob_birth hosp_surg_breast hosp_surg_other hosp_inf hosp_neo hosp_heme hosp_endo hosp_psych hosp_neuro hosp_ent hosp_cv hosp_resp hosp_gi hosp_derm hosp_msk hosp_renal hosp_uro_male hosp_breast hosp_uro_female hosp_preg hosp_ob_hemodynamics hosp_postop_comp hosp_fall hosp_other hosp_hernia

     global title: di ///
	    "Table 3: Cause of hospitalization among live kidney donors. "
     global excelfile: di "Table3_LKD_Hosp_Cause" // global byvar 
     global contvars  firsthosp_yr hosp_count hh_income s_date
     global binaryvars insurance_post $hosp_code
	 global multivars race_howell
	 
     global footnotes1 firsthosp_yr hosp_count hh_income
     global footnotes2 insurance_post $hosp_code
	  global footnotes3 race_howell

     //command
     which table1_options
     table1_options, ///           
	 title("$title") ///  by($byvar)
		 cont($contvars) ///
		 binary($binaryvars) ///
		 multi($multivars)  ///
		 foot("$footnotes1 $footnotes2 $footnotes3") ///
		 excel("$excelfile") 

table1, ///
vars(firsthosp_yr conts \ hosp_count conts \ hosp_surg_any bin \ hosp_surg_ortho bin \ hosp_surg_gi bin \  hosp_surg_gyn bin \  hosp_surg_ob_birth bin \  hosp_surg_breast bin \  hosp_surg_other bin \ hosp_msk bin \ hosp_gi bin \ hosp_cv bin \ hosp_neuro bin \ hosp_uro_female  bin \ hosp_renal bin \ hosp_neo bin \ hosp_endo bin \ hosp_breast bin \ hosp_ent bin \ hosp_resp bin \ hosp_inf bin \ hosp_psych bin \ hosp_preg bin \ hosp_heme bin \ hosp_fall bin \  hosp_derm bin \ hosp_uro_male bin \ hosp_other bin ) ///
onecol cformat(%3.0f) format(%3.0f) cmissing ///
saving(hosp_cause_${cdat}, replace)

**#Table3 (demo of hosp vs nonhosp)
clear all
use hosp_final.dta, clear
     global title: di ///
	    "Table 2. Comparing baseline demographic, health, and socioeconomic characteristics of live kidney donors among LKDs who were hospitalized versus never hospitalized."
     global excelfile: di "Table2_LKD_HospvsNohosp"
     global byvar hosp_bin 
	 
     global contvars tx_age last_pretx_sbp last_pretx_dbp last_pretx_bmi ckdepi_pre hh_income adi_natrank
     global binaryvars female hxsmk pre_hx_dm pre_hx_htn insurance_pre college_bin
     global multivars race_howell tx_center edu_whole edu_srtr 
	 
     global footnotes1 tx_age last_pretx_sbp last_pretx_dbp last_pretx_bmi ckdepi_pre hh_income adi_natrank
     global footnotes2 female hxsmk pre_hx_dm pre_hx_htn insurance_pre college_bin
     global footnotes3 race_howell tx_center edu_whole edu_srtr 
	 

     //command
     which table1_options
     table1_options, ///           
	 title("$title") ///  
	 by($byvar) ///
		 cont($contvars) ///
		 binary($binaryvars) ///
		 multi($multivars)  ///
		 foot("$footnotes1 $footnotes2 $footnotes3") ///
		 excel("$excelfile") 
		 
table1, ///
by(hosp_bin) ///
vars(tx_age conts \ female bin \ race_howell cat \ hxsmk bin \ hh_income conts \ college_bin bin \ edu_whole cat \ adi_natrank conts \ adi_bin bin \ pre_hx_htn bin \ pre_hx_dm bin \ ckdepi_pre conts \  last_pretx_sbp conts \ last_pretx_dbp conts \ last_pretx_bmi conts \ insurance_pre bin \ srtr_pre_insurance_type cat \ tx_center cat) ///
onecol cformat(%3.0f) format(%3.0f) cmissing ///
saving(hosp_bin_${cdat}, replace)


