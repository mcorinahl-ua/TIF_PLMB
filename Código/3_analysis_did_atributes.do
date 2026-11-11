/*==================================================
Name:           2_analysis_did_atributes.do

Project:        Difference in Differences (DiD)
                Outcome: Variables físicas
Author:         Maria Corina Hernandez
E-email:        mc.hernandezl12@uniandes.edu.co

----------------------------------------------------
Creation Date:  03 Feb 2026
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
global dir_dist "${dir_0}Dropbox\RA Andes - TIF\Alvaro\1. Entregables\Entregable 2 - Modelación de escenarios fiscales y financieros\Memoria de Cálculo y Comentarios\\"

** Paquetes 
** ssc install cem
** ssc install outreg2

/*==================================================
      1: Revisar variación en atributos físicos 
==================================================*/

** Importar los datos procesados
use "${dir_proc}predios_proc.dta", clear

* Calcular desviación del área construida y de número de pisos
bys id_predio: egen sd_area = sd(area_construida)
gen cambio_area = sd_area > 0
tab cambio_area

bys id_predio: egen sd_pisos = sd(max_num_piso)
gen cambio_pisos = sd_pisos > 0
tab cambio_pisos

* Calcular diferencia entre área máxima y mínima
bys id_predio: egen max_area = max(area_construida)
bys id_predio: egen min_area = min(area_construida)
gen delta_area = max_area - min_area
sum delta_area, d
drop max_area min_area

* Revisar primer año de cambio en área
bys id_predio (year): gen d_area = area_construida != area_construida[_n-1] ///
    if _n > 1
bys id_predio: egen first_change_area = min(cond(d_area==1, year, .))
tab first_change_area

* Revisar correlación con tratamiento (800m)
tab cambio_area treatment_800, row
tab cambio_pisos treatment_800, row

/*==================================================
      1.5: Revisar la variación a nivel manzana
==================================================*/

use "${dir_proc}predios_proc.dta", clear

egen codigo_manzana_join = concat(c_barrio c_manzana)

/* Colapsar las variables a nivel de código de manzana y año 
Para el panel balanceado (solamente predios existentes en toda la línea
de tiempo
*/

collapse (mean) treatment_* tramo codigo_estrato ///
		 (sum) area_terreno valor_avaluo area_construida /// 
		 max_num_piso  avaluo_total_puntual_com , /// 
		 by(codigo_barrio codigo_manzana_join year)
		 
** Corregir variable de tratamiento
foreach v in treatment_400 treatment_800 treatment_1200 {
    replace `v' = (`v' > 0.65) if !missing(`v')
}
		 
tempfile areas
save `areas', replace

** Eliminar aquellas manzanas adyacentes a la línea de intervención

import delim "${dir_raw}SHAPES\manzanas_linea_interv.csv", clear varnames(1) delim(";")

tostring mancodigo, replace

	** Corregir la estructura del código de manzana para el pegue
gen aux = substr(mancodigo, 5, 7) if strlen(mancodigo) == 7
tab aux
	** Todos los dígitos iniciales son 0. 
replace aux = substr(aux, 2, 3)
replace mancodigo = "00" + substr(mancodigo, 1, 4) + aux if strlen(mancodigo) == 7
drop aux

ren mancodigo codigo_manzana_join

tempfile manzanas_drop
save  `manzanas_drop', replace

** Importar las áreas calculadas con los predios completos (no solamente panel balanceado)
use "${dir_dist}manzanas_uso_suelo.dta", clear

** Eliminar manzanas de línea de intervención
//merge m:1 codigo_manzana_join using `manzanas_drop', nogen keep(master)

** Pegar variables existentes y áreas calculadas
merge 1:1 codigo_manzana_join year using `areas', keep(matched)

** Guardar base a nivel manzana
save "${dir_proc}manzanas_proc.dta", replace

/* Estadísticas descriptivas de las áreas construidas a nivel manzana */

bys year : sum area_construida_total area_residencial if treatment_400 == 1
bys year : sum area_construida_total area_residencial if treatment_800 == 1
bys year : sum area_construida_total area_residencial if treatment_1200 == 1

* Calcular desviación del área construida y de número de pisos
bys codigo_manzana_join: egen sd_area = sd(area_construida_total)
gen cambio_area = sd_area > 0
tab cambio_area

bys codigo_manzana_join: egen sd_pisos = sd(max_num_piso)
gen cambio_pisos = sd_pisos > 0
tab cambio_pisos

* Calcular diferencia entre área máxima y mínima
bys codigo_manzana_join: egen max_area = max(area_construida_total)
bys codigo_manzana_join: egen min_area = min(area_construida_total)
gen delta_area = max_area - min_area
sum delta_area, d
drop max_area min_area

* Revisar promedios por tratamiento (800m)
sum delta_area if treatment_800 == 1
sum delta_area if treatment_800 == 0

/*==================================================
      2: Realizar la estimación
==================================================*/
sort codigo_manzana_join year

by codigo_manzana_join: gen delta_area_it = ///
    area_construida_total - area_construida_total[_n-1] if _n>1

	gen intervencion_it = delta_area_it > 0


*--- Estimación DiD

/* Crear variable del DiD
Cambiar variable treatment (400, 800, 1200) dependiendo de la definición 
del tratamiento. 
*/

gen treat = cond(treatment_400==1 & year>=2019,1,0)

** Estimar el DiD 
#d;
	reghdfe intervencion_it treat, 
		a(codigo_manzana_join year)
		vce(cluster codigo_barrio);
#d cr 

** Output
outreg2 using "${dir_outcomes}DID_atributes.docx", word keep(treat) append

*--- Estimacion DiD con ventanas de tiempo para 800m

gen ln_area_cons = log(area_construida_total)

forvalues i=2014/2025 {
	gen trat_`i' = cond(year==`i',1*treatment_800,0)
	la var trat_`i' "`i'"
}

** Estimar el DiD 
replace trat_2018=0
#d;
	reghdfe ln_area_cons trat_*, 
		a(codigo_manzana_join year)
		vce(cluster codigo_barrio);
#d cr 
estimates store didwin_area

#d;
	coefplot didwin_area, keep(trat_*) vertical yline(0) omitted 
		title("Área Construida") ytitle("ATT");
#d cr 

graph export "${dir_outcomes}DiD_windows_area.pdf", replace 

/*==================================================
  3: Spatial Boundary Discontinuity Design con AIM
==================================================*/

** Importamos códigos de manzanas tratadas por AIM
import delim "${dir_raw}SHAPES\manzanas_treat_aim.csv", clear

	** Corregir la estructura del código de manzana para el pegue
tostring mannumero manseccat, replace

replace mannumero = "0" + mannumero if strlen(mannumero) == 1
replace manseccat = "00" + manseccat if strlen(manseccat) == 4
egen codigo_manzana_join = concat( manseccat mannumero)

** Generamos variable de tratamiento
gen treat_aim = 1

tempfile manz_aim_tr
save  `manz_aim_tr', replace

** Importamos códigos de manzanas no tratadas con AIM
import delim "${dir_raw}SHAPES\manzanas_untreat_aim_donut.csv", clear

	** Corregir la estructura del código de manzana
tostring mannumero manseccat, replace

replace mannumero = "0" + mannumero if strlen(mannumero) == 1
replace manseccat = "00" + manseccat if strlen(manseccat) == 4
egen codigo_manzana_join = concat( manseccat mannumero)

** Generar variable de tratamiento
gen treat_aim = 0

keep codigo_manzana_join treat_aim

** Juntar
append using `manz_aim_tr', keep(codigo_manzana_join treat_aim)

save  `manz_aim_tr', replace

** Pegamos a la base de procesadas
use "${dir_proc}manzanas_proc.dta", clear

merge m:1 codigo_manzana_join using `manz_aim_tr', nogen keep(matched)

** Realizar la estimación
gen ln_area_cons = log(area_construida_total)

gen treat = cond(treat_aim==1 & year>2019,1,0)

** Estimar el DiD 
#d;
	reghdfe ln_area_cons treat, 
		a(codigo_manzana_join year)
		vce(cluster codigo_barrio);
#d cr 

** Output
outreg2 using "${dir_outcomes}DID_atributes_aim.docx", word keep(treat) append

exit
/* End of do-file */

