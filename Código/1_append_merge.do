/*==================================================
Name:           1_append_merge.do

Project:        Procesar y limpiar base de datos catastral
Author:         Maria Corina Hernandez
E-email:        mc.hernandezl12@uniandes.edu.co

----------------------------------------------------
Creation Date:  30 Jan 2026
Output:         predios.dta
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
      1: Importar y pegar datos
==================================================*/

tempfile base

* Combinar tablas de datos catastrales anuales

	import delim "${dir_raw}INFORMACIÓN CATASTRAL Y PREDIAL\PREDIO_FINAL_2014.csv", varnames(1) clear
	
	ren (codigo_usop_14 avaluo_total_puntual_com_2014)(codigo_usop avaluo_total_puntual_com)
	gen year = 2014

save `base', emptyok

forvalues y = 15/25 {
    import delimited ///
        "${dir_raw}INFORMACIÓN CATASTRAL Y PREDIAL\PREDIO_FINAL_20`y'.csv", ///
        varnames(1) clear
    
		ren (codigo_usop_`y' avaluo_total_puntual_com_20`y')(codigo_usop avaluo_total_puntual_com)
	
    gen year = 20`y'
    append using `base'
    save `base', replace
}

* Crear una variable indicadora de predio

egen id_predio = group(codigo_barrio codigo_manzana codigo_predio codigo_construccion codigo_resto)

bys id_predio: gen T = _N
tab T

* Guardar el archivo con todos los predios en todos los años. 

save "${dir_proc}predios_completos.dta", replace

* Quedarnos solo con aquellos predios observados en todos los años. 

drop if T != 12

* Guardar el archivo del panel balanceado de predios. 

save "${dir_proc}predios_balanceado.dta", replace

/*==================================================
      2: Estandarizar ID
==================================================*/

** Importar panel a nivel de Barrio-Manzana-Predio-Construcción-Año
use "${dir_proc}predios_balanceado.dta", clear

** Crear codigos String 
global cod_vars "codigo_barrio codigo_manzana codigo_predio"

foreach var in $cod_vars {
	cap tostring `var', gen(`var'_str)
}
	
** Estandarizar los codigos String como la base del Shapefile	
gen c_barrio = substr("000000"+codigo_barrio_str,-6,.)
gen c_manzana = substr("00"+codigo_manzana_str,-2,.)
gen c_predio = substr("00"+codigo_predio_str,-2,.)

** Crear código único de lote
egen codigo_lote = concat(c_barrio c_manzana c_predio)

save "${dir_proc}predios_balanceado.dta", replace

/*==================================================
      3: Juntar DBF con panel
==================================================*/

* Combinar con datos espaciales de tratamiento y tramo (creadas con ArcGIS)

import dbase "${dir_raw}SHAPES\Lotes_catastrales.gdb.zip.gdrive\Lotes_catastrales.dbf", clear

ren *, lower
ren (codigo_lot treatment treatment_ treatment1 tramo) (codigo_lote treatment_800 treatment_1200 treatment_400 tramo_800)

label variable treatment_800 "800m"
label variable treatment_1200 "1200m"
label variable treatment_400 "400m"
label variable tramo_800 "tramos en 800m"

tab tramo treatment_800, mis

	* Dos observaciones son duplicados
duplicates drop codigo_lote, force

* Quitar predios rurales y de Sumapaz
drop if cod_upz == "1" | cod_upz == "3" | cod_upz == "4" | cod_upz == "5"

save "${dir_proc}predios_tratamiento_shp.dta", replace

* Juntar bases de predios con datos geoespaciales

use "${dir_proc}predios_balanceado.dta", clear

merge m:1 codigo_lote using "${dir_proc}predios_tratamiento_shp.dta", keep(matched)

/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                       188,666
        from master                   131,496  (_merge==1)
        from using                     57,170  (_merge==2)

    Matched                        27,592,548  (_merge==3)
    -----------------------------------------
*/

* El resultado es un panel catastral balanceado e incorporando las variables de tratamiento y tramo. 

save "${dir_proc}predios.dta" , replace

exit
/* End of do-file */


