/*==================================================
Name:           4_analysis_cem.do

Project:        Coarsened Exact Matching (CEM)
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
**ssc install cem

/*==================================================
      1: Importar y pegar distancias
==================================================*/

** Importar distancia al CBD
import delim "${dir_dist}Distancias_Manzanas-CBD.csv", clear

** Crear codigos String 
cap tostring man_codigo, gen(man_codigo_str)

** Agregar leading 0 donde no esté
replace man_codigo_str = "00" + man_codigo_str if strlen(man_codigo_str) == 7
ren (man_codigo man_codigo_str total_leng) (man_codigo_og man_codigo dist_cbd)

** Revisar distribución de la variable de distancia para crear las cohortes
centile dist_cbd, centile( 5 25 50 75 95 )

/* 
                                                          Binom. interp.   
    Variable |       Obs  Percentile    Centile        [95% conf. interval]
-------------+-------------------------------------------------------------
  total_leng |    42,635          5     3667.37        3589.914    3759.018
             |                   25    9242.638        9187.286    9300.016
             |                   50    12661.31        12610.16    12721.59
             |                   75    16281.16        16221.58    16338.29
             |                   95    19952.99        19896.18    20014.43
*/

xtile dist_cbd_p = dist_cbd, nq(5)
label define distp 1 "P0–20" 2 "P20–40" 3 "P40–60" 4 "P60–80" 5 "P80–100"
label values dist_cbd_p distp

tempfile cbd
save `cbd', replace

** Importar distancia a PLMB
import delim "${dir_dist}Distancias_Manzanas-TrazadoPLMB.csv", clear

** En este archivo los códigos de manzana ya están correctos 
ren total_length dist_plmb

** Revisar distribución de la variable de distancia para crear las cohortes
centile dist_plmb, centile( 5 25 50 75 95 )

/*
                                                          Binom. interp.   
    Variable |       Obs  Percentile    Centile        [95% conf. interval]
-------------+-------------------------------------------------------------
   dist_plmb |    42,635          5    449.4775        435.7532    463.2817
             |                   25    2103.467        2062.918    2144.428
             |                   50    5031.646        4962.781    5096.853
             |                   75    8341.881        8275.049    8417.196
             |                   95    12393.55        12344.68    12438.21
*/

xtile dist_plmb_p = dist_plmb, nq(5)
label define distp 1 "P0–20" 2 "P20–40" 3 "P40–60" 4 "P60–80" 5 "P80–100"
label values dist_plmb_p distp

tempfile plmb
save `plmb', replace

** Importar distancia a la estación de Transmilenio más cercano
import delim "${dir_dist}Distancias_Manzanas-TM.csv", clear

** En este archivo los códigos de manzana ya están correctos 
ren total_length dist_tm

** Revisar distribución de la variable de distancia para crear las cohortes
centile dist_tm, centile( 5 25 50 75 95 )

/*
                                                          Binom. interp.   
    Variable |       Obs  Percentile    Centile        [95% conf. interval]
-------------+-------------------------------------------------------------
     dist_tm |    42,635          5    392.9919        385.6287    399.3504
             |                   25    1004.109        992.0176    1015.556
             |                   50    1807.936        1790.789    1826.007
             |                   75    2908.431        2877.323    2937.882
             |                   95    5069.387        5040.703    5110.162
*/

xtile dist_tm_p = dist_tm, nq(5)
label define distp 1 "P0–20" 2 "P20–40" 3 "P40–60" 4 "P60–80" 5 "P80–100"
label values dist_tm distp

tempfile tm
save `tm', replace

** Importar distancia a la Malla Vial Arterial
import delim "${dir_dist}Distancias_Manzanas-MallaVialArterial.csv", clear

** En este archivo los códigos de manzana ya están correctos
ren total_length dist_malla

** Revisar distribución de la variable de distancia para crear las cohortes
centile dist_malla, centile( 5 25 50 75 95 )

/*
                                                          Binom. interp.   
    Variable |       Obs  Percentile    Centile        [95% conf. interval]
-------------+-------------------------------------------------------------
  dist_malla |    43,695          5    64.67325        62.57101    66.81625
             |                   25    239.9879        237.0525    243.0352
             |                   50     449.683        445.2172    454.2293
             |                   75     783.826        775.6545    791.7683
             |                   95    1937.811        1894.737    1982.492
*/

xtile dist_malla_p = dist_malla, nq(5)
label define distp 1 "P0–20" 2 "P20–40" 3 "P40–60" 4 "P60–80" 5 "P80–100"
label values dist_malla distp

tempfile malla_arterial
save `malla_arterial', replace

/*==================================================
      2: Importar datos 
==================================================*/

** Importar los datos 
use "${dir_proc}predios_proc", clear

** Dejar solo el periodo antes del tratamiento 
keep if year==2018 

** Eliminar la variable de año 
drop year

** Crear código de manzana para pegue
replace c_manzana = "0" + c_manzana
egen man_codigo = concat(c_barrio c_manzana)

** Merge archivos de distancia con base principal predios_proc
local file_list malla_arterial tm cbd plmb

foreach d of local file_list {

    merge m:1 man_codigo using ``d'', keep(matched) nogen

}

/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                        28,050
        from master                    26,060  (merge_malla_arterial==1)
        from using                      1,990  (merge_malla_arterial==2)

    Matched                         2,273,319  (merge_malla_arterial==3)
    -----------------------------------------

    Result                      Number of obs
    -----------------------------------------
    Not matched                       119,940
        from master                   119,940  (merge_tm==1)
        from using                          0  (merge_tm==2)

    Matched                         2,181,429  (merge_tm==3)
    -----------------------------------------

    Result                      Number of obs
    -----------------------------------------
    Not matched                       119,942
        from master                   119,941  (merge_cbd==1)
        from using                          1  (merge_cbd==2)

    Matched                         2,181,428  (merge_cbd==3)
    -----------------------------------------

    Result                      Number of obs
    -----------------------------------------
    Not matched                       119,941
        from master                   119,941  (merge_plmb==1)
        from using                          0  (merge_plmb==2)

    Matched                         2,181,429  (merge_plmb==3)
    -----------------------------------------
*/


/*==================================================
      3: Arreglar las variables que son 
		 base del matching
==================================================*/

/* Crear variables dummy a partir del destino 
   del inmueble */
   
** Predios del Estado -- se excluyen
drop if inlist(descripcion_destino, ///
    "VIAS", "ESPACIO PÚBLICO", "LOTE DEL ESTADO", ///
    "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO", ///
	"NO URBANIZ/SUELO PROTEG", "TIERRAS IMPRODUCTIVAS")
   

** Residencial 
gen dest_residencial = (descripcion_destino=="RESIDENCIAL")

** Comercial
#d;
	gen dest_comercial = inlist(descripcion_destino,
		"COMERCIO EN CORREDOR COM",
		"COMERCIO PUNTUAL",
		"COMERCIO EN CENTRO COMER",
		"PARQUEADEROS");
#d cr

** Industrial
#d;
	gen dest_industrial = inlist(descripcion_destino,
		"INDUSTRIAL",
		"AGROINDUSTRIAL");
#d cr

** Agricola / rural
#d;
	gen dest_agricola = inlist(descripcion_destino,
		"AGRICOLA",
		"AGROPECUARIO",
		"PECUARIO",
		"FORESTAL",
		"PREDIO RURAL PARCEL. NO EDIFI.");
#d cr

drop if dest_agricola == 1

** Urbanizado no edificado
#d;
      gen dest_urban_noedif = inlist(descripcion_destino, 
	  "URBANIZADO NO EDIFICADO");
#d cr 

** Dotacional Privado
#d;
      gen dest_dotac = inlist(descripcion_destino, 
	  "DOTACIONAL PRIVADO");
#d cr 

** Otros privados
#d;
	  gen dest_otros = (dest_residencial==0 & 
                        dest_comercial==0 & 
                        dest_industrial==0 & 
                        dest_agricola==0 &
						dest_urban_noedif==0 &
						dest_dotac==0);
#d cr 

** Generar variable de fragmentación de lote

bys codigo_lote: egen n_constr_lote = nvals(codigo_construccion)

/*==================================================
      4: Coarsened Exact Matching (CEM)
==================================================*/
// set seed 12345


* Tomar una muestra aleatoria del 5%
// sample 0.05

** Realizar el CEM y crear los pesos
#d;
	cem codigo_estrato (0 1.5 2.5 3.5 4.5 5.5 6.5)
	area_construida max_num_piso 
	dest_residencial dest_comercial 
	dest_industrial dest_urban_noedif 
	dest_dotac dest_otros dist_cbd n_constr_lote, treatment(treatment_800);
#d cr

** Inspeccionar las observaciones con match
tab treatment_800 cem_matched

** Guardar la base completa
save "${dir_proc}treat_CEM.dta", replace

** Dejar solo las observaciones con match 
drop if cem_matched==0

** Dejar solo las variables relevantes para el match 
#d; 
	keep codigo_lote cem_weights cem_matched 
		 cem_strata codigo_construccion codigo_resto;
#d cr 

** Guardar la base con los pesos
save "${dir_proc}treat_weights.dta", replace

/*==================================================
      5: Pegar al panel y realizar la estimación
==================================================*/

*--- Merge con el panel  original 
#d;
	merge 1:m codigo_lote codigo_construccion codigo_resto 
		using "${dir_proc}predios_proc", gen(_pegados);
#d cr

/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                    11,105,028
        from master                         0  (_pegados==1)
        from using                 11,105,028  (_pegados==2)

    Matched                        16,487,520  (_pegados==3)
    -----------------------------------------
*/

drop if _pegados==2
drop _pegados

*--- Estimación 

** Crear variable del DiD
gen treat = cond(treatment_800==1 & year>=2019,1,0)

** Estimar el DiD 
#d;
	reghdfe ln_avaluo_real_2014 treat [aweight=cem_weights], 
		a(codigo_lote year)
		vce(robust);
#d cr 

** Output
outreg2 using "${dir_outcomes}DID_CEM.docx", word keep(treat) append

exit
/* End of do-file */

><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

Notes:
1. 
2. 

Version Control:

