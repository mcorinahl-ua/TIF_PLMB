/*==================================================
Name:           3_analysis_did_heter.do

Project:        Difference in Differences (DiD) con efectos heterogéneos
                Outcome: valor_avaluo
Author:         Maria Corina Hernandez
E-email:        mc.hernandezl12@uniandes.edu.co

----------------------------------------------------
Creation Date:  04 Feb 2026
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
** ssc install reghdfe
** ssc install coefplot

/*==================================================
      1: Importar datos y crear categorías
==================================================*/

** Importar los datos 
use "${dir_proc}predios_proc.dta", clear

/*==================================================
      2: Heterogeneidad por Destino Económico
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
          1 | 22,515,652       83.99       83.99
          2 |  4,103,792       15.31       99.30
          3 |    180,529        0.67       99.97
          4 |      7,033        0.03      100.00
------------+-----------------------------------
      Total | 26,807,006      100.00
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

/*==================================================
      Realizar la estimación
==================================================*/

*--- Estimación DiD para destinos

** Crear variable del DiD
gen treat = cond(treatment_1200==1 & year>=2019,1,0)

** Estimar el DiD 

/* Tomamos como base el destino económico residencial 
*/

#d;
	reghdfe ln_avaluo_real_2014 
		c.treat##i.dest_cat_pre, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr 

** Output
outreg2 using "${dir_outcomes}DID_heter_dest.docx", word keep(treat dest_cat_pre dest_cat_pre#c.treat) append ctitle("AI 1200")

*--- Estimación DiD para cambio de destino (LPM)

#d;
	reghdfe cambio_destino_it 
		c.treat##i.dest_cat_pre, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr 

** Output
outreg2 using "${dir_outcomes}DID_heter_dest.docx", word keep(treat dest_cat_pre dest_cat_pre#c.treat) append ctitle("dest_cambio")

** Estimar el DiD para estratos

/* Tomamos como base el estrato 6
*/

preserve 

drop if estr_pre == 0
replace estr_pre = 0 if estr_pre == 6

#d;
	reghdfe ln_avaluo_real_2014 
		c.treat##i.estr_pre if dest_cat == 2, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr 

restore 

** Output
outreg2 using "${dir_outcomes}DID_heter_estr.docx", word keep(treat estr_pre estr_pre#c.treat) append ctitle("AI 1200")

*--- Estimacion DiD solo residencial

#d;
reghdfe ln_avaluo_real_2014 
    treat
    if dest_cat_pre==2,
    a(codigo_lote year)
    vce(cluster codigo_barrio);
#d cr 

** Output
outreg2 using "${dir_outcomes}DID_heter_dest_res.docx", word keep(treat) append ctitle("AI 1200")

/*
*--- Estimación residencial ventanas de tiempo

forvalues i=2014/2025 {
	gen trat_`i' = cond(year==`i',1*treatment_1200,0)
	la var trat_`i' "`i'"
}

** Estimar el DiD 
replace trat_2018=0

#d;
	reghdfe ln_avaluo_real_2014 trat_* if dest_cat_pre == 2, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr 

estimates store didwin_dest	

honestdid, pre(1/5) post(6/12) coefplot

coefplot didwin_dest, ///
    keep(trat_*) vertical ///
    yline(0) ///
	xlab(, angle(45)) ///
	title("Destino Residencial") ///
    name(dest, replace)

graph export "${dir_outcomes}DiD_windows_dest.pdf", replace 
*/
	
/*==================================================
      3: Heterogeneidad por Tramo
==================================================*/
	
** Estimar el DiD 

#d;
reghdfe ln_avaluo_real_2014 
    c.treat##i.tramo, 
    a(codigo_lote year) 
    vce(cluster codigo_barrio);
#d cr 

** Output
outreg2 using "${dir_outcomes}DID_heter_tram.docx", word keep(treat tramo#c.treat) append ctitle("AI 1200")
	
*--- Estimacion DiD con ventanas de tiempo 

* Ventanas dinámicas por tramo
forvalues y = 2014/2025 {
    forvalues t = 1/3 {
        gen trat_`y'_tr`t' = ///
            (year==`y' & treatment==1 & tramo==`t')
        label var trat_`y'_tr`t' "`y' x Tramo `t'"
    }
}

** Estimar el DiD 
foreach t in 1 2 3 {
    replace trat_2018_tr`t' = 0
}

#d;
reghdfe ln_avaluo_real_2014 
    trat_*, 
    a(codigo_lote year) 
    vce(cluster codigo_barrio);
#d cr 

estimates store didwin_tramo


coefplot didwin_tramo, ///
    keep(trat_*_tr1) vertical ///
    yline(0) ///
	xlab(, angle(45)) ///
	title("Tramo 1") ///
    name(tr1, replace)

coefplot didwin_tramo, ///
    keep(trat_*_tr2) vertical ///
    yline(0) ///
	xlab(, angle(45)) ///
	title("Tramo 2") ///
    name(tr2, replace)

coefplot didwin_tramo, ///
    keep(trat_*_tr3) vertical ///
    yline(0) ///
	xlab(, angle(45)) ///
	title("Tramo 3") ///
    name(tr3, replace)
	
graph combine tr1 tr2 tr3, ///
    col(3) ///
    title("Valor catastral por tramo") ///
    ycommon	xcommon

graph export "${dir_outcomes}DiD_windows_tram.pdf", replace 


exit
/* End of do-file */
	
