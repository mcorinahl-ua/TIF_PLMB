/*==================================================
Name:           6_nueva_ai.do

Project:        Correr pipeline con la nueva área de influencia
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
      1: Importar y pegar datos de predios en el AI
==================================================*/

tempfile base

* Combinar tablas de datos catastrales anuales

	import delim "${dir_raw}Nueva Área de Influencia\BASE_NUEVA_AI_2014.csv", varnames(1) clear
	
	ren (codigo_usop_14 avaluo_total_puntual_com_2014)(codigo_usop avaluo_total_puntual_com)
	gen year = 2014

save `base', emptyok

forvalues y = 15/25 {
    import delimited ///
        "${dir_raw}Nueva Área de Influencia\BASE_NUEVA_AI_20`y'.csv", ///
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

/*==================================================
      2: Estandarizar ID en tratados
==================================================*/

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


/*==================================================
      3: Juntar panel con controles 
==================================================*/

preserve 

use "${dir_proc}predios_completos.dta", clear
duplicates drop id_predio year, force

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

tempfile predios_merge
save `predios_merge', replace

restore

merge 1:1 codigo_lote codigo_construccion codigo_resto year using `predios_merge', gen(ai_tratamiento)

/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                    24,710,924
        from master                         0  (_merge==1)
        from using                 24,710,924  (_merge==2)

    Matched                         6,973,318  (_merge==3)
    -----------------------------------------
*/

save `predios_merge', replace

/*==================================================
      3: Juntar panel con datos UPZ 
==================================================*/

* Combinar con datos de UPZ (creadas con ArcGIS)

import dbase "${dir_raw}SHAPES\Lotes_catastrales.gdb.zip.gdrive\Lotes_catastrales.dbf", clear

ren *, lower
ren (codigo_lot treatment treatment_ treatment1 tramo) (codigo_lote treatment_800 treatment_1200 treatment_400 tramo_800)
duplicates drop codigo_lote, force
keep codigo_lote cod_upz nombre_upz 

* Merge
merge 1:m codigo_lote using `predios_merge', keep (using matched) nogen

/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                       326,813
        from master                         0  (_merge==1)
        from using                    326,813  (_merge==2)

    Matched                        31,357,429  (_merge==3)
    -----------------------------------------
*/

/* Comprobamos que los missings en cod_upz efectivamente corresponden a zonas que
se deben excluir del análisis */

tab cod_upz, mis
tab year if cod_upz == ""

* Quitar predios rurales y de Sumapaz
drop if cod_upz == "1" | cod_upz == "3" | cod_upz == "4" | cod_upz == "5"
drop if cod_upz == ""

/*==================================================
      4: Volver precios reales
==================================================*/

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
save "${dir_proc}predios_proc_ai2.dta", replace


/*==================================================
      5: Realizar la estimación
==================================================*/

*--- Estimación DiD

gen treatment = 0
replace treatment = 1 if ai_tratamiento == 3

** Crear variable del DiD
gen treat = cond(treatment==1 & year>=2019,1,0)

** Estimar el DiD 
** Excluimos los predios cuyo destino económico son vías y predios propiedad del Estado 

#d;
	reghdfe ln_avaluo_real_2014 treat if !inlist(descripcion_destino, ///
    "VIAS", "ESPACIO PÚBLICO", ///
    "LOTE DEL ESTADO", "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO"), 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr 

*--- Estimacion DiD con ventanas de tiempo 

forvalues i=2014/2025 {
	gen trat_`i' = cond(year==`i',1*treatment,0)
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


/*==================================================
      7: Heterogeneidad por Destino Económico
==================================================*/

	/* Crear variable categórica a partir del destino 
	económico del predio */
  
** Predios del Estado -- se excluyen
drop if inlist(descripcion_destino, ///
    "VIAS", "ESPACIO PÚBLICO", "LOTE DEL ESTADO", ///
    "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO", ///
	"NO URBANIZ/SUELO PROTEG", "TIERRAS IMPRODUCTIVAS")
   
gen dest_cat = .
		
** Agrícola/Rural = 1
replace dest_cat = 1 if inlist(descripcion_destino, ///
		"AGRICOLA", ///
		"AGROPECUARIO", ///
		"PECUARIO", ///
		"FORESTAL", ///
		"PREDIO RURAL PARCEL. NO EDIFI.")

** Residencial = 2
replace dest_cat = 2 if descripcion_destino=="RESIDENCIAL"

** Comercial = 3
replace dest_cat = 3 if inlist(descripcion_destino, ///
		"COMERCIO EN CORREDOR COM", ///
		"COMERCIO PUNTUAL", ///
		"COMERCIO EN CENTRO COMER", ///
		"PARQUEADEROS")
		
** Industrial = 4
replace dest_cat = 4 if inlist(descripcion_destino, ///
		"INDUSTRIAL", ///
		"AGROINDUSTRIAL")


/* Urbanizado no edificado = 5
Se ubica en suelo urbano y tiene un potencial directo de capitalización por el 
Metro. Entonces es clave para expectativas y especulación. 
*/
replace dest_cat = 5 if descripcion_destino=="URBANIZADO NO EDIFICADO"

/* Dotacional Privado = 6
Siendo predios "destinados al desarrollo de actividades de interés público o social,
como educación, salud, culto, cultura o recreación" responden a incentivos privados, 
pero distintos de residencial y comercio. Reaccionan distinto al Metro (hospitales,
colegios)
*/
replace dest_cat = 6 if descripcion_destino=="DOTACIONAL PRIVADO"

** Otros privados = 7
replace dest_cat = 7 if dest_cat==.

** Etiquetar
label define dest_cat 1 "Agrícola" 2 "Residencial" 3 "Comercial" 4 "Industrial" ///
                     5 "Urbanizado no edificado" ///
                     6 "Dotacional privado" 7 "Otros privados"
label values dest_cat dest_cat

drop if dest_cat == 1

** Se observan lotes que cambian de destino
sort codigo_lote year
bys codigo_lote: egen n_destinos = nvals(dest_cat)
tab n_destinos

/*
 n_destinos |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 | 23,810,132       78.39       78.39
          2 |  5,859,939       19.29       97.68
          3 |    649,273        2.14       99.82
          4 |     52,411        0.17       99.99
          5 |      3,444        0.01      100.00
------------+-----------------------------------
      Total | 30,375,199      100.00
*/

** Generar binaria de cambio de destino
sort codigo_lote year

by codigo_lote: gen cambio_destino_it = ///
    dest_cat != dest_cat[_n-1] ///
    if year == year[_n-1] + 1
	
replace cambio_destino_it = 0 if year != 2014 & cambio_destino_it == . 

** Fijamos el destino económico pre-tratamiento
bys codigo_lote (year): ///
    gen dest_cat_pre = dest_cat if year < 2019

bys codigo_lote (year): ///
    replace dest_cat_pre = dest_cat_pre[_n-1] if missing(dest_cat_pre)

bys codigo_lote: ///
    replace dest_cat_pre = dest_cat_pre[_N]

** Fijamos el estrato pre-tratamiento
bys codigo_lote (year): ///
    gen estr_pre = codigo_estrato if year < 2019

bys codigo_lote (year): ///
    replace estr_pre = estr_pre[_n-1] if missing(estr_pre)

bys codigo_lote: ///
    replace estr_pre = estr_pre[_N]
	
	** Guardar base con variables de destinos económicos
save "${dir_proc}predios_proc_ai2.dta", replace

/*==================================================
      Realizar la estimación
==================================================*/

*--- Estimación DiD para destinos

** Estimar el DiD 

/* Tomamos como base el destino económico residencial 
*/

#d;
	reghdfe ln_avaluo_real_2014 
		c.treat##i.dest_cat_pre, 
		a(codigo_lote year, savefe)
		vce(cluster codigo_barrio);
#d cr 

** Output
outreg2 using "${dir_outcomes}DID_heter_dest.docx", word keep(treat dest_cat_pre dest_cat_pre#c.treat) append ctitle("AI Vías")

** Estimar el DiD para estratos

/* Tomamos como base el estrato 6
*/ 

drop if estr_pre == 0
replace estr_pre = 0 if estr_pre == 6

#d;
	reghdfe ln_avaluo_real_2014 
		c.treat##i.estr_pre if dest_cat == 2, 
		a(codigo_lote year, savefe)
		vce(cluster codigo_barrio);
#d cr 

** Output
outreg2 using "${dir_outcomes}DID_heter_estr.docx", word keep(treat estr_pre estr_pre#c.treat) append ctitle("AI Vías")

*--- Estimacion DiD solo residencial

#d;
reghdfe ln_avaluo_real_2014 
    treat
    if dest_cat_pre==2,
    a(codigo_lote year)
    vce(cluster codigo_barrio);
#d cr 

** Output
outreg2 using "${dir_outcomes}DID_heter_dest_res.docx", word keep(treat) append ctitle("AI Vías")



/*==================================================
      8: Heterogeneidad por Tramo
==================================================*/

* Combinar con datos espaciales de tramo (creadas con ArcGIS)
import delim "${dir_raw}SHAPES\manzanas_AI_vias_tramos.csv", clear

		ren *, lower

			* 50 observaciones son duplicados
		duplicates drop codigo_uni, force

		* Generar código correcto de manzana

		** Crear codigos String 
		global cod_vars "codigo_bar codigo_man"

		foreach var in $cod_vars {
			cap tostring `var', gen(`var'_str)
		}

		gen c_barrio = substr("000000"+codigo_bar_str,-6,.)
		gen c_manzana = substr("00"+codigo_man_str,-2,.)

		drop mancodigo
		egen mancodigo = concat(c_barrio c_manzana)

		* Archivo temporal
		tempfile tramos
		save `tramos', replace


use "${dir_proc}predios_proc_ai2.dta", clear

* Generar código correcto de manzana
drop mancodigo
egen mancodigo = concat(c_barrio c_manzana)

* Juntar bases de predios con datos geoespaciales
merge m:1 mancodigo using `tramos', keep(master matched)

/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                    23,585,601
        from master                23,584,800  (_merge==1)
        from using                        801  (_merge==2)

    Matched                         6,790,399  (_merge==3)
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

** Output
outreg2 using "${dir_outcomes}DID_heter_tram.docx", word keep(treat tramo#c.treat) append ctitle("AI Vías")
	


