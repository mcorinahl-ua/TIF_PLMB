/*==================================================
Name:           Predict.do

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
El presente do-file genera el archivo prediccion_SDH_2025_2026.csv, insumo
predio a predio para la Secretaría Distrital de Hacienda. Se estima un modelo
DiD heterogéneo por estrato socioeconómico definido en el periodo pre-tratamiento (c.treat##i.estr_pre) con efectos fijos de lote (α_i) y año (γ_t) 
absorbidos vía reghdfe. El valor ajustado 2025 (avaluo_fitted_2025) corresponde 
al fitted value completo del modelo convertido a pesos nominales mediante el
deflactor IPC acumulado desde 2014; ya incorpora el efecto causal del metro
(δ) diferenciado por estrato. El contrafactual (avaluo_sinmetro_2025) sustrae
ese δ para obtener el avalúo que habría tenido el predio sin el metro, y
delta_metro_pct expresa la prima como porcentaje. Para 2026 se presentan tres
escenarios. El conservador (avaluo_2026_flat) mantiene el valor real de 2025
ajustando únicamente por el IPC proyectado del Banrep (6.3%), sin dinámica
adicional de mercado ni capitalización nueva del metro. El de tendencia
(avaluo_2026_trend) añade la extrapolación lineal del cambio observado en el
FE de año entre 2024 y 2025 (Δγ = γ_2025 − γ_2024), componente que refleja
la dinámica reciente del mercado inmobiliario bogotano y puede contener
expectativas difusas de capitalización por la mayor credibilidad de la obra.
El optimista (avaluo_2026_optimista) incorpora además una ronda adicional de
capitalización directa del metro, aproximado como el efecto causal total
estimado dividido, bajo el supuesto de que en 2026 la obra sigue
generando plusvalía al ritmo promedio histórico. 
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

* Modelo heterogéneo por estrato con FEs guardados

#d;
	reghdfe ln_avaluo_real_2014 
		c.treat##i.estr_pre if dest_cat == 2 & !missing(estr_pre), 
		absorb(codigo_lote year, savefe)
		vce(cluster codigo_barrio)
		resid;
#d cr 

* Preservar los FEs de estrato
rename __hdfe1__ fe_estr_lote
rename __hdfe2__ fe_estr_year

* Modelo heterogéneo por destino con FEs guardados
#d;
	reghdfe ln_avaluo_real_2014 
		c.treat##i.dest_cat_pre, 
		a(codigo_lote year, savefe)
		vce(cluster codigo_barrio)
		resid;
#d cr

* Valor ajustado completo (EF predio α_i + EF año γ_t + coeficientes Xβ)
predict ln_avaluo_pred, xbd

* Preservar los FEs de destino
rename __hdfe1__ fe_dest_lote
rename __hdfe2__ fe_dest_year 

* Verificar FE 
describe fe_*

* Tendencia del FE de año: Δγ = γ_2025 − γ_2024
* fe_dest_year es el year FE (segundo término del absorb), constante dentro de cada año
sum fe_dest_year if year == 2025, meanonly
scalar gamma_2025 = r(mean)
sum fe_dest_year if year == 2024, meanonly
scalar gamma_2024 = r(mean)
scalar delta_gamma = gamma_2025 - gamma_2024

* Delta en log atribuible al metro, por estrato (0 para no tratados)
gen delta_ln = 0

*── Residencial (dest_cat_pre == 2): modelo residencial por estrato ──────────
* Base: estr_pre == 0 (estrato 6 recodificado)
replace delta_ln = -0.00                          if treat==1 & dest_cat_pre==2 & estr_pre==0
replace delta_ln =  0.2659489             if treat==1 & dest_cat_pre==2 & estr_pre==1
replace delta_ln =  0.1841864             if treat==1 & dest_cat_pre==2 & estr_pre==2
replace delta_ln =  0.1577741             if treat==1 & dest_cat_pre==2 & estr_pre==3
replace delta_ln = 0.0902845             if treat==1 & dest_cat_pre==2 & estr_pre==4
replace delta_ln =  0.0357388             if treat==1 & dest_cat_pre==2 & estr_pre==5

*── Otros destinos: modelo por destino económico ─────────────────────────────
replace delta_ln = _b[treat] + _b[3.dest_cat_pre#c.treat]  if treat==1 & dest_cat_pre==3
replace delta_ln = _b[treat] + _b[4.dest_cat_pre#c.treat]  if treat==1 & dest_cat_pre==4
replace delta_ln = _b[treat] + _b[5.dest_cat_pre#c.treat]  if treat==1 & dest_cat_pre==5
replace delta_ln = _b[treat] + _b[6.dest_cat_pre#c.treat]  if treat==1 & dest_cat_pre==6
replace delta_ln = _b[treat] + _b[7.dest_cat_pre#c.treat]  if treat==1 & dest_cat_pre==7

* Corte 2025 y conversión a pesos nominales (cum_mult del merge IPC)
keep if year == 2025

* Multiplicador nominal 2026
* Para 2026 se utiliza el IPC PROYECTADO 2026 del Banco de la República
scalar ipc_proy_2026 = 6.3
gen cum_mult_2026 = cum_mult * (1 + ipc_proy_2026 / 100)

*── 2025 
gen avaluo_fitted_2025   = exp(ln_avaluo_pred) * cum_mult
gen avaluo_sinmetro_2025 = exp(ln_avaluo_pred - delta_ln) * cum_mult
gen delta_metro_pct      = (exp(delta_ln) - 1) * 100

*── 2026
* 1) Conservador: γ_2026 = γ_2025 y solo sube por IPC
gen avaluo_2026_flat     = exp(ln_avaluo_real_2014) * cum_mult_2026

* 2) Tendencia: γ_2026 = γ_2025 + Δγ continuando la dinámica real reciente
gen avaluo_2026_trend    = exp(ln_avaluo_real_2014 + delta_gamma) * cum_mult_2026

* 3) Tendencia más capitalización γ_2026 = γ_2025 + Δγ + capitalización metro. 
gen avaluo_2026_premium = exp(ln_avaluo_real_2014 + delta_gamma + delta_ln) * cum_mult_2026

*── Etiquetas 
label var avaluo_fitted_2025   "Avalúo ajustado 2025 - modelo (nominal)"
label var avaluo_sinmetro_2025 "Contrafactual sin metro 2025 (nominal)"
label var delta_metro_pct      "Prima metro (%)"
label var avaluo_2026_flat     "Proyección 2026 - gamma plano (nominal)"
label var avaluo_2026_trend    "Proyección 2026 - gamma tendencia lineal (nominal)"
label var avaluo_2026_premium  "Proyección 2026 - con premium: γ tendencia + δ metro"

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

* Exportar la base 
* Dejamos solo las manzanas en el AI 
// keep if ai_tratamiento == 3

* Dejamos las variables de interés
#d ;
keep chip valor_avaluo impuesto_ajustado 
	descripcion_destino codigo_estrato
	avaluo_fitted_2025 avaluo_sinmetro_2025
	avaluo_2026_trend avaluo_2026_premium
	delta_metro_pct ai_tratamiento;
#d cr

* Exportar
export delimited using "${dir_proc}prediccion_SDH_2025_2026.csv", replace

