/*================================================== 
Name:           8_robustez_control.do

Project:        Correr los modelos con una definición alternativa de grupo control
Author:         Maria Corina Hernandez
E-email:        mc.hernandezl12@uniandes.edu.co

----------------------------------------------------
Creation Date:  17 Mar 2026
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

/*================================================== 
		1: Crear grupo control
==================================================*/

import delim "${dir_raw}SHAPES\manzanas_contrafac.csv", clear

** Crear codigos String 
global cod_vars "manseccat  mannumero"

foreach var in $cod_vars {
	cap tostring `var', gen(`var'_str)
}

ren mancodigo mancodigo_og
	
** Estandarizar los codigos String como la base del Shapefile	
gen c_barrio = substr("000000"+manseccat_str,-6,.)
gen c_manzana = substr("000"+mannumero_str,-3,.)

** Crear código único de manzana
egen mancodigo = concat(c_barrio c_manzana)

** Crear variable de control
gen treatment = 0

** Quedarnos solo con lo necesario
keep mancodigo treatment 

** Pegar con base de predios
merge 1:m mancodigo treatment using "${dir_proc}predios_proc_ai2.dta", gen(control)
tab control treatment

keep if (treatment == 1 & control == 2) | (treatment == 0 & control == 3)

drop control

/*================================================== 
		2: Estimar el DiD
==================================================*/

** Estimar el DiD 
** Excluimos los predios cuyo destino económico son vías y predios propiedad del Estado 

#d;
	reghdfe ln_avaluo_real_2014 treat, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr 

** Estimar el DiD con valor comercial y ventanas de tiempo
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

*--- Estimación DiD para destinos
/* Tomamos como base el destino económico residencial 
*/

#d;
	reghdfe ln_avaluo_real_2014 
		c.treat##i.dest_cat_pre, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr 

** Estimar el DiD para estratos

/* Tomamos como base el estrato 6
*/ 

drop if estr_pre == 0
replace estr_pre = 0 if estr_pre == 6

#d;
	reghdfe ln_avaluo_real_2014 
		c.treat##i.estr_pre if dest_cat == 2, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr 

*--- Estimacion DiD solo residencial

#d;
reghdfe ln_avaluo_real_2014 
    treat
    if dest_cat_pre==2,
    a(codigo_lote year)
    vce(cluster codigo_barrio);
#d cr 

*--- Estimación DiD con heterogeneidad por tramos

preserve 

* Combinar con datos espaciales de tramo (creadas con ArcGIS)
import delim "${dir_raw}SHAPES\manzanas_AI_vias_tramos.csv", clear

		ren *, lower
		duplicates drop codigo_uni, force

		* Generar código correcto de manzana
		global cod_vars "codigo_bar codigo_man"

		foreach var in $cod_vars {
			cap tostring `var', gen(`var'_str)
		}

		gen c_barrio = substr("000000"+codigo_bar_str,-6,.)
		gen c_manzana = substr("000"+codigo_man_str,-3,.)

		drop mancodigo
		egen mancodigo = concat(c_barrio c_manzana)

		* Archivo temporal
		tempfile tramos
		save `tramos', replace

restore

* Juntar bases de predios con datos geoespaciales
merge m:1 mancodigo using `tramos', keep(master matched)

/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                     5,721,746
        from master                 5,720,400  (_merge==1)
        from using                      1,346  (_merge==2)

    Matched                         5,008,545  (_merge==3)
    -----------------------------------------
*/

* Reemplazar tramo = 0 para predios fuera del Área de Influencia

replace tramo = 0 if tramo == .

** Estimar el DiD 

#d;
reghdfe ln_avaluo_real_2014 
    c.treat##i.tramo, 
    a(codigo_lote year) 
    vce(cluster codigo_barrio);
#d cr 


