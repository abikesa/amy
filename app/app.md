

From: Vincent Jin <zjin26@jhmi.edu>
Date: Friday, November 8, 2024 at 2:01 PM
To: Chang, Amy <changa23@ecu.edu>, Amy Chang <achang78@jhmi.edu>
Cc: Abimereki Muzaale <muzaale@jhmi.edu>
Subject: Re: Live Kidney Donor Hospitalization Calculator
Hi Amy,

Thank you so much for reaching out! 

For the calculator, I think we will need s0 data, beta coefficient matrix, and variance matrix. An excel with all Cox regression results would also be helpful if the categorical variables are labeled. :)

For codes, I think you can do:

```{stata}
capture drop s0
stcox ....., basesurv(s0)
matrix cox = r(table)'
matrix cox_b = e(b)'
matrix cox_v = e(V)'

putexcel set cox_results, replace
putexcel A1 = matrix(cox), names
putexcel set cox_beta, replace 
putexcel A1 = matrix(cox_b), names
putexcel set cox_var, replace
putexcel A1 = matrix(cox_v), names

preserve
set varabbrev off
keep _st _t _d _t0 s0
set varabbrev on
export delimited sinfo, replace
restore
```

Hope this helps!

Thanks, 
Vincent Jin
 
From: Chang, Amy <changa23@ecu.edu>
Sent: Friday, November 8, 2024 12:20:51 PM
To: Vincent Jin <zjin26@jhmi.edu>
Cc: Abimereki Muzaale <muzaale@jhmi.edu>
Subject: Re: Live Kidney Donor Hospitalization Calculator 
 

      External Email - Use Caution      


Hi Vincent,

I apologize for the redundant multiple emails. I do not regularly check my JHMI email anymore, so please let me knwo if there is anything else that I can do help with this process via my ECU email address.

Best regards,
Amy
 
From: Abimereki Muzaale <muzaale@jhmi.edu>
Sent: November 8, 2024 12:12 PM
To: Chang, Amy <changa23@ecu.edu>
Subject: FW: Live Kidney Donor Hospitalization Calculator 
 
	You don't often get email from muzaale@jhmi.edu. Learn why this is important 

This email originated from outside ECU.

 
 
From: Amy Chang <achang78@jhmi.edu>
Date: Friday, November 8, 2024 at 12:11 PM
To: Vincent Jin <zjin26@jhmi.edu>
Cc: Abimereki Muzaale <muzaale@jhmi.edu>
Subject: Live Kidney Donor Hospitalization Calculator
Hi Vincent,
 
My name is Amy Chang, and I work with Abi on the live kidney donor hospitalization manuscript, which we have added you to the author list.  Abi and I met today, and I am sharing with you the lines of code that need to be edited in order to get output for the app. 
 
 
Sincerely,
 Amy
