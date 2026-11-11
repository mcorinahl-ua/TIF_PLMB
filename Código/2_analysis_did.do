/*==================================================
Name:           2_analysis_did.do

Project:        Difference in Differences (DiD)
                Outcome: valor_avaluo
Author:         Maria Corina Hernandez
E-email:        mc.hernandezl12@uniandes.edu.co

----------------------------------------------------
Creation Date:  02 Feb 2026
Output:         
==================================================*/

/*==================================================
              0: Program set up
==================================================*/

clear all
set more off

** Path
global dir_0 "C:\Users\USUARIO\\"
//global dir_0 "C:\Users\proyecto\\"

** Data
global dir_data "${dir_0}Dropbox\RA Andes - TIF\Datos\\"
global dir_raw "${dir_data}raw\\"
global dir_proc "${dir_data}processed\\"
global dir_outcomes "${dir_0}Documents\GitHub\TIF_PLMB\Datos\outcomes\\"
global dir_dist "${dir_0}Dropbox\RA Andes - TIF\Datos\processed\distancias_paper\\"

** Paquetes 
** ssc install cem
** ssc install outreg2

/*==================================================
      1: Importar datos y volver precios reales
==================================================*/

** Importar los datos 
use "${dir_proc}predios.dta", clear

*--- Importar datos de inflación y limpiarlos
preserve

** Import Data
#d;
	import excel using "${dir_data}inflacion.xlsx", 
		sheet("Series de datos") cellrange(A718:B850)
		clear;
#d cr 

** Dejar solo diciembre
keep if month(A)==12

** Renombrar variable
rename (A B) (date inflation)

** Extraer el año
gen year = year(date)

** Dejar las variables relevantes
keep year inflation

** Ordenar por año 
sort year 

** Factor de inflación = (1 + inflación/100)
gen double infl_factor = 1 + inflation/100

** En el año base (2014) el factor debe ser 1
replace infl_factor = 1 if year == 2014

** Multiplicador de inflación acumulada desde 2014 hasta el año t
gen double cum_mult = .
replace cum_mult = 1 if year == 2014

** Cálculo recursivo:
** cum_mult_t = cum_mult_{t-1} * infl_factor_t
replace cum_mult = cum_mult[_n-1] * infl_factor if year > 2014

** Crear archivo temporal 
tempfile infl
save `infl' 

restore 

merge m:1 year using `infl', nogen  

*---- Convertir variables a precios reales constantes 2014 

** Precios reales en moneda de 2014
gen avaluo_real_2014 = valor_avaluo / cum_mult

#d;
	gen avaluo_com_real_2014 = 
						avaluo_total_puntual_com / cum_mult;
#d cr

** Convertir a logaritmo
gen ln_avaluo_real_2014 = log(avaluo_real_2014)
gen ln_avaluo_com_2014 = log(avaluo_com_real_2014)

** Guardar base con valores reales

save "${dir_proc}predios_proc.dta", replace

/*==================================================
      2: Realizar la estimación
==================================================*/

*--- Estimación DiD

** Crear variable del DiD
gen treat = cond(treatment_1200==1 & year>=2019,1,0)

** Estimar el DiD 
#d;
	reghdfe ln_avaluo_real_2014 treat , 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr 

*--- Estimacion DiD con ventanas de tiempo 

forvalues i=2014/2025 {
	gen trat_`i' = cond(year==`i',1*treatment_1200,0)
	la var trat_`i' "`i'"
}


** Estimar el DiD 
replace trat_2018=0
#d;
	reghdfe ln_avaluo_real_2014 trat_*, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr 
estimates store didwin

#d;
	coefplot didwin, keep(trat_*) vertical yline(0) omitted 
		title("Avalúo Catastral") ytitle("ATT");
#d cr 
graph export "${dir_outcomes}DiD_windows_1200.pdf", replace 

** Estimar el DiD con valor comercial
#d;
	reghdfe ln_avaluo_com_2014 trat_*, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr 
estimates store didwin_com

#d;
	coefplot didwin_com, keep(trat_*) vertical yline(0) omitted
		title("Avaluo Comercial") ytitle("ATT");
#d cr 
graph export "${dir_outcomes}DiD_windows_com_1200.pdf", replace 

/*==================================================
      3: Estimación sin predios públicos y vías
==================================================*/

** Excluimos los predios cuyo destino económico son vías y predios propiedad del Estado y 

** Estimar el DiD 
#d;
	reghdfe ln_avaluo_real_2014 treat if !inlist(descripcion_destino, ///
    "VIAS", "ESPACIO PÚBLICO", ///
    "LOTE DEL ESTADO", "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO"), 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr 

** Output
outreg2 using "${dir_outcomes}DID_simple.docx", word keep(treat) replace

*--- Estimacion DiD con ventanas de tiempo 

** Estimar el DiD 
#d;
	reghdfe ln_avaluo_real_2014 trat_* if !inlist(descripcion_destino, ///
    "VIAS", "ESPACIO PÚBLICO", ///
    "LOTE DEL ESTADO", "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO"), 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr 
estimates store didwin_filtered

#d;
	coefplot didwin_filtered, keep(trat_*) vertical yline(0) omitted 
		title("Avaluo Catastral") ytitle("ATT");
#d cr 

graph export "${dir_outcomes}DiD_windows_filter.pdf", replace 

exit
/* End of do-file */

><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

Notes:
1. 
2. 

Version Control:

