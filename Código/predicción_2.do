/*==================================================
Name:           Predicción.do

Project:        Utilizar coeficientes para predecir valores de 2026
Author:         Maria Corina Hernandez
E-email:        mc.hernandezl12@uniandes.edu.co

----------------------------------------------------
Creation Date:  16 Abr 2026
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
      Predicción — Avalúos ajustados 2025
==================================================*/

/*
El presente do-file genera el archivo prediccion_SDH_2025_2026.csv. Todas las variables de avalúo se expresan en pesos reales de 2014 (unidades naturales del modelo). Se estiman dos modelos con efectos fijos de lote (α_i) y año (γ_t). La predicción final (ln_avaluo_pred) combina ambos modelos: residenciales usan
el fitted del modelo 1; no residenciales usan el del modelo 2.

El contrafactual (avaluo_sinmetro_2025) sustrae delta_ln para obtener el
avalúo que habría tenido el predio sin el metro; delta_metro_pct expresa la
prima como porcentaje. 

Para 2026 se presentan tres escenarios, todos en pesos reales 2014. El conservador (avaluo_2026_flat) replica el valor real 2025 sin 
cambio alguno. El de tendencia (avaluo_2026_trend) añade la extrapolación
lineal del efecto fijo de año entre 2024 y 2025. El optimista
(avaluo_2026_premium) incorpora además una ronda adicional anualizada de 
capitalización del metro (δ), bajo el supuesto de que en 2026 la obra sigue
 generando plusvalía al ritmo histórico.
*/

* Importar base de datos completa
// use "${dir_0}Desktop\predios_proc_ai2\predios_proc_ai2.dta", clear
// use "${dir_proc}predios_proc_ai2.dta", clear
 
* Importar base de datos de control robusto (contiguo a la zona de influencia)
 use "${dir_proc}predios_ai2_contr_rob.dta", clear

* Exclusiones de estrato
drop if missing(estr_pre)
replace estr_pre = . if estr_pre == 0
replace estr_pre = 0 if estr_pre == 6

* Modelo 1: estrato socioeconómico (solo residencial) 

#d;
	reghdfe ln_avaluo_real_2014
		c.treat##i.estr_pre if dest_cat == 2 & !missing(estr_pre),
		absorb(codigo_lote year, savefe)
		vce(cluster codigo_barrio)
		resid;
#d cr

* Fitted value y residuos del modelo de estrato
predict ln_pred_estr, xbd
predict resid_estr, resid

rename __hdfe1__ fe_estr_lote
rename __hdfe2__ fe_estr_year

* Modelo 2: destino económico (resto de destinos)

#d;
	reghdfe ln_avaluo_real_2014
		c.treat##i.dest_cat_pre,
		a(codigo_lote year, savefe)
		vce(cluster codigo_barrio)
		resid;
#d cr

* Fitted value y residuos del modelo de destino
predict ln_avaluo_pred, xbd
predict resid_dest, resid

rename __hdfe1__ fe_dest_lote
rename __hdfe2__ fe_dest_year

* Combinar predicciones
* Residenciales: ln_pred_estr usa FEs y δ del modelo de estrato
* No residenciales: ln_avaluo_pred usa FEs y δ del modelo de destino
replace ln_avaluo_pred = ln_pred_estr if dest_cat_pre == 2 & !missing(ln_pred_estr)

* Verificar FEs
describe fe_*

* Tendencia del efecto fijo de año
sum fe_dest_year if year == 2025, meanonly
scalar gamma_2025 = r(mean)
sum fe_dest_year if year == 2024, meanonly
scalar gamma_2024 = r(mean)
scalar delta_gamma = gamma_2025 - gamma_2024

* Delta en log atribuible al metro, por estrato/destino (0 = no tratados)
gen delta_ln = 0

* Residencial (dest_cat_pre == 2): coeficientes del modelo de estrato
replace delta_ln = -0.00          if treat==1 & dest_cat_pre==2 & estr_pre==0
replace delta_ln =  0.2659489     if treat==1 & dest_cat_pre==2 & estr_pre==1
replace delta_ln =  0.1841864     if treat==1 & dest_cat_pre==2 & estr_pre==2
replace delta_ln =  0.1577741     if treat==1 & dest_cat_pre==2 & estr_pre==3
replace delta_ln =  0.0902845     if treat==1 & dest_cat_pre==2 & estr_pre==4
replace delta_ln =  0.0357388     if treat==1 & dest_cat_pre==2 & estr_pre==5

* Otros destinos: coeficientes del modelo de destino
replace delta_ln = _b[treat] + _b[3.dest_cat_pre#c.treat]  if treat==1 & dest_cat_pre==3
replace delta_ln = _b[treat] + _b[4.dest_cat_pre#c.treat]  if treat==1 & dest_cat_pre==4
replace delta_ln = _b[treat] + _b[5.dest_cat_pre#c.treat]  if treat==1 & dest_cat_pre==5
replace delta_ln = _b[treat] + _b[6.dest_cat_pre#c.treat]  if treat==1 & dest_cat_pre==6
replace delta_ln = _b[treat] + _b[7.dest_cat_pre#c.treat]  if treat==1 & dest_cat_pre==7

* Corte 2025
keep if year == 2025

*** 2025
gen avaluo_fitted_2025   = exp(ln_avaluo_pred)
gen avaluo_sinmetro_2025 = exp(ln_avaluo_pred - delta_ln)
gen delta_metro_pct      = (exp(delta_ln) - 1) * 100

*** 2026 — pesos reales de 2014
* Flat: valor real 2025 sin cambio (= avaluo_fitted_2025)
gen avaluo_2026_flat    = exp(ln_avaluo_pred)

* Tendencia: extrapola cambio observado entre 2024 y 2025
gen avaluo_2026_trend   = exp(ln_avaluo_pred + delta_gamma)

* Premium: tendencia y ronda adicional de capitalización
	* Capitalización anual del metro 
	* n_post = años de tratamiento 2019–2025
	scalar n_post = 6

	* Divide el δ acumulado entre los años de tratamiento.
	gen delta_ln_anual = delta_ln / n_post

	* Escenario con premium
	gen avaluo_2026_premium = exp(ln_avaluo_pred + delta_gamma + delta_ln_anual)

* Factor anual completo (mercado + metro) para 2026 a 2027
gen aumento_anual = exp(delta_gamma + delta_ln_anual)  if treat == 1
replace aumento_anual = exp(delta_gamma)               if treat == 0

* Etiquetas
label var avaluo_fitted_2025   "Avalúo ajustado 2025 - modelo (pesos reales 2014)"
label var avaluo_sinmetro_2025 "Contrafactual sin metro 2025 (pesos reales 2014)"
label var delta_metro_pct      "Prima metro (%)"
label var avaluo_2026_flat     "Proyección 2026 - gamma plano (pesos reales 2014)"
label var avaluo_2026_trend    "Proyección 2026 - gamma tendencia lineal (pesos reales 2014)"
label var avaluo_2026_premium  "Proyección 2026 - con premium: tendencia + metro (pesos reales 2014)"
label var aumento_anual 	   "Factor multiplicador anual (real 2014)"


* Merge con código CHIP
preserve 

import delim "C:\Users\USUARIO\Dropbox\RA Andes - TIF\Alvaro\2. Repositorio del Banco Mundial\INFORMACIÓN CATASTRAL Y PREDIAL\PREDIAL_CHIP\EMISION_2025.csv", clear

tempfile chip
save `chip', replace

restore 

merge 1:1 codigo_barrio codigo_manzana codigo_predio codigo_construccion codigo_resto using `chip', gen(merge_chip) keep (matched)

/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                     1,735,969
        from master                        62  (merge_chip==1)
        from using                  1,735,907  (merge_chip==2)

    Matched                         1,154,261  (merge_chip==3)
    -----------------------------------------
*/

* Dejamos solo las manzanas en el AI 
// keep if ai_tratamiento == 3

* Recodificar tratamiento
gen tratado = .
replace tratado = 1 if ai_tratamiento == 3
replace tratado = 0 if ai_tratamiento == 2

* Dejamos las variables de interés
#d ;
keep chip valor_avaluo avaluo_real_2014 impuesto_ajustado 
	descripcion_destino codigo_estrato
	avaluo_fitted_2025 avaluo_sinmetro_2025
	avaluo_2026_trend avaluo_2026_premium
	delta_metro_pct
	aumento_anual
	tratado;
#d cr

* Exportar
export delimited using "${dir_proc}prediccion_SDH_2025_2026.csv", replace