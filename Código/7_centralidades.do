/*================================================== 
Name:           7_centralidades.do

Project:        Construcción de índices urbanos a nivel manzana y merge a predios
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
args index_only dist_dir

** Path
global dir_0 "C:\Users\USUARIO\"

** Data
global dir_data "${dir_0}OneDrive - Universidad de los andes\RA Andes - TIF\Datos\"
global dir_raw "${dir_data}raw\"
global dir_proc "${dir_data}processed\"
global dir_outcomes "${dir_0}Documents\GitHub\TIF_PLMB\Datos\outcomes\"
global dir_dist "${dir_0}OneDrive - Universidad de los andes\Archivos de Alvaro Andres Casas Camargo - TIF - PLMB\1. Entregables\Entregable 2 - Modelación de escenarios fiscales y financieros\Memoria de Cálculo y Comentarios\Distancias\"
if "`dist_dir'" != "" global dir_dist "`dist_dir'\"


/*==================================================
      1: Importar distancias
==================================================*/

** Importar distancia al CBD
import delim "${dir_dist}Distancias_Manzanas-CBD.csv", clear

** Crear codigos String 
capture confirm string variable man_codigo
if _rc == 0 clonevar man_codigo_str = man_codigo
else tostring man_codigo, gen(man_codigo_str)

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
keep man_codigo dist_cbd dist_cbd_p

tempfile cbd
save `cbd', replace

** Importar distancia a PLMB
import delim "${dir_dist}Distancias_Manzanas-TrazadoPLMB.csv", clear

** En este archivo los códigos de manzana ya están correctos 
cap ren total_length dist_plmb
cap ren total_leng dist_plmb

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
keep man_codigo dist_plmb dist_plmb_p

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
label values dist_tm_p distp
keep man_codigo dist_tm dist_tm_p

tempfile tm
save `tm', replace

** Importar distancia a la Malla Vial Arterial
import delim "${dir_dist}Distancias_Manzanas-MallaVialArterial.csv", clear

** Crear codigos String 
capture confirm string variable man_codigo
if _rc == 0 clonevar man_codigo_str = man_codigo
else tostring man_codigo, gen(man_codigo_str)

** Agregar leading 0 donde no esté
replace man_codigo_str = "00" + man_codigo_str if strlen(man_codigo_str) == 7
cap ren total_length total_leng
ren (man_codigo man_codigo_str total_leng) (man_codigo_og man_codigo dist_malla)

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
label values dist_malla_p distp
keep man_codigo dist_malla dist_malla_p

tempfile malla_arterial
save `malla_arterial', replace


/*==================================================
      2: Pegar distancias
==================================================*/

** Importar los datos 
use "${dir_0}OneDrive - Universidad de los andes\RA Andes - TIF\Alex\base_bogota_270221.dta", clear

** Merge archivos de distancia con base principal predios_proc
local file_list malla_arterial tm cbd plmb

foreach d of local file_list {
    merge m:1 man_codigo using ``d'',  nogen keep(master matched)
}

/*
 Result                      Number of obs
    -----------------------------------------
    Not matched                           583
        from master                       583  
        from using                          0  

    Matched                            38,535  
    -----------------------------------------
(label distp already defined)

    Result                      Number of obs
    -----------------------------------------
    Not matched                         1,268
        from master                     1,268  
        from using                          0  

    Matched                            37,850  
    -----------------------------------------
(label distp already defined)

    Result                      Number of obs
    -----------------------------------------
    Not matched                         1,268
        from master                     1,268  
        from using                          0  

    Matched                            37,850  
    -----------------------------------------
(label distp already defined)

    Result                      Number of obs
    -----------------------------------------
    Not matched                         1,268
        from master                     1,268  
        from using                          0  

    Matched                            37,850  
    -----------------------------------------
*/


* Verificar llave
isid man_codigo

* Índice estructural del paper: PC1 de siete distancias de red a nivel manzana.
* Los ceros son distancias válidas; calcularlo antes de modificarlas para los inversos.
local red dist_sitp dist_alime dist_trans dist_vart dist_vinte dist_vtron dist_vloc
foreach var of local red {
    assert `var' >= 0 & !missing(`var')
    gen double a_`var' = -ln(1 + `var')
}

pca a_dist_sitp a_dist_alime a_dist_trans a_dist_vart a_dist_vinte a_dist_vtron a_dist_vloc
predict double A_pc1 if e(sample), score
quietly correlate A_pc1 a_dist_trans
if r(rho) < 0 replace A_pc1 = -A_pc1
egen double A_std = std(A_pc1)
egen double A_rank0 = rank(A_std)
count if !missing(A_std)
gen double A_rank = A_rank0 / r(N)
label var A_std "Accesibilidad estructural (PC1, estandarizada)"
label var A_rank "Rango percentil de accesibilidad estructural"
drop a_dist_* A_pc1 A_rank0

/*================================================== 
		3. Generar Índice de ACCESIBILIDAD DE TRANSPORTE (transport_access)
==================================================*/

* Evitar división por cero
foreach var in dist_vtron dist_vloc dist_vinte {
    replace `var' = . if `var' <= 0
}


* Inversos de distancia
gen inv_vtron = 1 / dist_vtron
gen inv_vloc  = 1 / dist_vloc
gen inv_vinte = 1 / dist_vinte


* Estandarización (z-score)
foreach var in inv_vtron inv_vloc inv_vinte {
    egen z_`var' = std(`var')
}

/***********************
* Índice de transporte simple (promedio)
************************/

egen transport_access = rowmean(z_inv_vtron z_inv_vloc z_inv_vinte)

label var transport_access "Accesibilidad por red vial (estandarizada)"

/***********************
* Índice de transporte Tipo Gravedad
************************/

* Parámetro de decaimiento
local gamma = 0.5

* Evitar ceros
foreach var in dist_vtron dist_vloc dist_vinte {
    replace `var' = . if `var' <= 0
}

* Fricción de distancia (no lineal)
gen f_vtron = 1 / (dist_vtron^`gamma')
gen f_vloc  = 1 / (dist_vloc^`gamma')
gen f_vinte = 1 / (dist_vinte^`gamma')

* Accesibilidad combinada
egen friction_index = rowmean(f_vtron f_vloc f_vinte)

/*********************************
* Índice de transporte exponencial
**********************************/

* Parámetro de decaimiento
local lambda = 0.01   

* Evitar ceros
foreach var in dist_vtron dist_vloc dist_vinte {
    replace `var' = . if `var' <= 0
}

* Decaimiento exponencial
gen exp_vtron = exp(-`lambda' * dist_vtron)
gen exp_vloc  = exp(-`lambda' * dist_vloc)
gen exp_vinte = exp(-`lambda' * dist_vinte)


* Accesibilidad de transporte
egen transport_access_exp = rowmean(exp_vtron exp_vloc exp_vinte)

/*================================================== 
		4. Generar Índices de ACCESO ECONÓMICO (economic_access)
==================================================*/

* Log de empleo (evitar log(0))
gen log_emp = log(1 + tot_emp_mz)

** Índice basado en promedio simple
gen economic_access = log_emp * transport_access

label var economic_access "Acceso a oportunidades económicas"

** Grupos de accesibilidad
xtile access_group = economic_access, nq(5)

label var access_group "Quintiles de accesibilidad económica"

** Índice basado en gravedad 
gen economic_access_gr = log_emp * friction_index

label var economic_access_gr "Accesibilidad tipo gravedad (gamma=`gamma')"

** Índice basado en decaimiento
gen economic_access_exp = log_emp * transport_access_exp

label var economic_access_exp "Accesibilidad exponencial (lambda=`lambda')"


/*================================================== 
		5. Generar variable de centralidad
==================================================*/

* Verificar variable existente
assert dist_cbd > 0 if !missing(dist_cbd)

gen ln_dist_cbd = log(dist_cbd)

label var ln_dist_cbd "Log distancia al CBD"


* Quintiles CBD
xtile cbd_group = dist_cbd, nq(5)

label var cbd_group "Quintiles distancia CBD"

/*================================================== 
		6. Generar Índice de EQUIPAMIENTOS (amenities_index)
==================================================*/

* Lista de variables
local equip dist_educa dist_salud dist_entre dist_eqrec dist_eqpar

* Inversos
foreach var of local equip {
    replace `var' = . if `var' <= 0
    gen inv_`var' = 1 / `var'
}

* Estandarizar
foreach var of local equip {
    egen z_`var' = std(inv_`var')
}

* Índice

egen amenities_index = rowmean( ///
    z_dist_educa ///
    z_dist_salud ///
    z_dist_entre ///
    z_dist_eqrec ///
    z_dist_eqpar ///
)

label var amenities_index "Acceso a equipamientos"


/*================================================== 
		7. Merge manzanas a predios
==================================================*/

* Índice I_AccB de la consultoría. Se conserva para comparar; el paper usa A_std.
factor dist_sitp dist_alime dist_trans dist_vart dist_vinte dist_vtron dist_vloc dist_vext dist_vrura d_americas d_calle26 d_caracas d_carr10 d_jimenez d_nqscent d_nqssur , pcf

rotate, kaiser

predict factor*, regression
// Normalizar los valores de los factor scores

forvalues i = 1/7 {
      egen mini`i' = min(factor`i')
	  egen maxi`i' = max(factor`i')
	  generate nfactor`i' = (factor`i'- mini`i')/(maxi`i'- mini`i')
}


// Construyo un índice con el promedio simple de los factores agregados

matrix list e(Ev)
gen tot_eigen= 2.45597+2.04407+1.84161+1.35712+1.26725+1.17104+1.16792
// Los ponderadores

gen w_f1= 2.45597/tot_eigen
gen w_f2= 2.04407/tot_eigen
gen w_f3= 1.84161/tot_eigen
gen w_f4= 1.35712/tot_eigen
gen w_f5= 1.26725/tot_eigen
gen w_f6= 1.17104/tot_eigen
gen w_f7= 1.16792/tot_eigen

* Dimensión 1: Accesibilidad estructural
gen D1 = nfactor1
label variable D1 "Accesibilidad estructural"

gen WD1p = w_f1
label variable WD1p "Peso de la accesibilidad estructural en el índice"

* Dimensión 2: Periferia-ruralidad
gen D2 = nfactor2
label variable D2 "Periferia-ruralidad"

gen WD2p = w_f2
label variable WD2p "Peso de la periferia-ruralidad en el índice"

* Dimensión 3: Capilaridad urbana
gen D3 = .
replace D3 = (w_f3/(w_f3+w_f4))*nfactor3 + ///
             (w_f4/(w_f3+w_f4))*nfactor4
label variable D3 "Accesibilidad de capilaridad urbana"

gen WD34p = w_f3 + w_f4
label variable WD34p "Peso de la accesibilidad de capilaridad urbana en el índice"

* Dimensión 4: Corredores específicos
gen D4 = .
replace D4 = (w_f5/(w_f5+w_f6+w_f7))*nfactor5 + ///
             (w_f6/(w_f5+w_f6+w_f7))*nfactor6 + ///
             (w_f7/(w_f5+w_f6+w_f7))*nfactor7
label variable D4 "Accesibilidad de corredores específicos"

gen WD567p = w_f5 + w_f6 + w_f7
label variable WD567p "Peso de los corredores específicos en el índice"
// Ahora el índice Índice compuesto ponderado de Accesibilidad 

gen I_AccB=.
replace I_AccB=D1*WD1p+D2*WD2p+D3*WD34p+D4*WD567p




/*================================================== 
		8. Merge manzanas a predios
==================================================*/


* GUARDAR BASE DE MANZANA CON VARIABLES GENERADAS 
* EDITAR LA LISTA DE VARIABLES SEGÚN LA NECESIDAD
ren man_codigo mancodigo
keep mancodigo dist_plmb economic_access* access_group ln_dist_cbd cbd_group amenities_index I_AccB A_std A_rank

save "${dir_proc}manzanas_access.dta", replace

* Con el argumento 1, solo actualizar los índices que necesita el paper.
if "`index_only'" == "1" exit


use "${dir_proc}predios_proc_ai2.dta", clear

* Merge
merge m:1 mancodigo using "${dir_proc}manzanas_access.dta", gen(m_distancias)

* Verificar merge

drop if m_distancias == 2   // manzanas sin predios
drop m_distancias

/*================================================== 
		9. Modelos de efectos heterogéneos
==================================================*/

log using "${dir_outcomes}modelos_heter.smcl", replace

*---------------------------------------------------------------*
* Accesibilidad estructural del paper
*---------------------------------------------------------------*

gen post = cond( year >= 2019, 1, 0)
gen inv_dist_plmb = 1/(dist_plmb+1000)

#d;
	reghdfe ln_avaluo_real_2014 c.post##c.inv_dist_plmb##c.A_std,
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr


*---------------------------------------------------------------*
* Tratamiento continuo
*---------------------------------------------------------------*

#d;
	reghdfe ln_avaluo_real_2014 c.post##c.inv_dist_plmb, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr


*---------------------------------------------------------------*
* Accesibilidad económica continua
*---------------------------------------------------------------*

* 1) Accesibilidad medida con promedio simple
#d;
	reghdfe ln_avaluo_real_2014 c.treat##c.economic_access, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr

* 2) Accesibilidad medida con gravedad
#d;
	reghdfe ln_avaluo_real_2014 c.treat##c.economic_access_gr, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr

* 3) Accesibilidad medida con decaimiento
#d;
	reghdfe ln_avaluo_real_2014 c.treat##c.economic_access_exp, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr

*---------------------------------------------------------------*
* Accesibilidad económica por quintiles
*---------------------------------------------------------------*

#d;
	reghdfe ln_avaluo_real_2014 c.treat##i.access_group, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr

*---------------------------------------------------------------*
* Centralidad
*---------------------------------------------------------------*

#d;
	reghdfe ln_avaluo_real_2014 c.treat##c.ln_dist_cbd, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr

#d;
reghdfe ln_avaluo_real_2014 
    c.post#c.inv_dist_plmb#c.economic_access, 
    a(codigo_lote year) 
    vce(cluster codigo_barrio);
#d cr
	
margins, dydx(inv_dist_plmb) at(economic_access=(-0.2 0 0.1) post=1)

*---------------------------------------------------------------*
* Centralidad por quintiles
*---------------------------------------------------------------*

#d;
	reghdfe ln_avaluo_real_2014 c.treat##i.cbd_group, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr

*---------------------------------------------------------------*
* Equipamientos
*---------------------------------------------------------------*

#d;
	reghdfe ln_avaluo_real_2014 c.treat##c.amenities_index, 
		a(codigo_lote year)
		vce(cluster codigo_barrio);
#d cr

* Cerrar archivo log para guardar resultados. 
log close
