/*==================================================
Name:           5_robustez.do

Project:        Correr modelo con distintos buffers
Author:         Maria Corina Hernandez
E-email:        mc.hernandezl12@uniandes.edu.co

----------------------------------------------------
Creation Date:  04 Jan 2026
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
      1: Juntar DBF con panel
==================================================*/


* Combinar con datos espaciales de tratamiento y tramo (creadas con ArcGIS)

import dbase "${dir_raw}SHAPES\Lotes_catastrales_treat_robust\Lotes_catastrales_treat_robust.dbf", clear

ren *, lower
ren (codigo_lot treatment treatment_ treatment1 tramo) (codigo_lote treatment_800 treatment_1200 treatment_400 tramo_800)

label variable treatment_800 "800m"
label variable treatment_1200 "1200m"
label variable treatment_400 "400m"
label variable tramo_800 "tramos en 800m"

	* Dos observaciones son duplicados

duplicates drop codigo_lote, force

tempfile treatment_robust
save `treatment_robust', replace

* Juntar bases de predios con datos geoespaciales

use "${dir_proc}predios_proc.dta", clear

merge m:1 codigo_lote using `treatment_robust', nogen keep(matched)

/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                        58,729
        from master                         0  (merge_aux==1)
        from using                     58,729  (merge_aux==2)

    Matched                        27,592,548  (merge_aux==3)
    -----------------------------------------

El resultado es un panel catastral balanceado e incorporando las variables de tratamiento y tramo. 
*/

save "${dir_proc}predios_robust.dta" , replace


/*==================================================
      3: Estimación Área de Influencia 1200m 
==================================================*/

** Excluimos los predios cuyo destino económico son vías, y predios propiedad del Estado 

*--- Estimación DiD

** Crear variable del DiD para 1200m 
gen treat_1200 = cond(treatment_1200==1 & year>=2019,1,0)

** Estimar el DiD 
#d;
	reghdfe ln_avaluo_real_2014 treat_1200 if !inlist(descripcion_destino, ///
    "VIAS", "ESPACIO PÚBLICO", ///
    "LOTE DEL ESTADO", "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO"), 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr 

** Output
outreg2 using "${dir_outcomes}DID_simple.docx", word keep(treat_1200) append

/*==================================================
      3: Estimación Área de Influencia 400m 
==================================================*/

** Excluimos los predios cuyo destino económico son vías, y predios propiedad del Estado 

*--- Estimación DiD

** Crear variable del DiD para 400m 
gen treat_400 = cond(treatment_400==1 & year>=2019,1,0)

** Estimar el DiD 
#d;
	reghdfe ln_avaluo_real_2014 treat_400 if !inlist(descripcion_destino, ///
    "VIAS", "ESPACIO PÚBLICO", ///
    "LOTE DEL ESTADO", "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO"), 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr 

** Output
outreg2 using "${dir_outcomes}DID_simple.docx", word keep(treat_400) append


exit
/* End of do-file */


