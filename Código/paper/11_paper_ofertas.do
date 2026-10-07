*==================================================
* 11_paper_ofertas.do
* Compara ofertas de propiedad horizontal y avalúos en 2025.
* 1 Oct 2026. Requiere Ofertas_PH_CIB_2025.xlsx y manzanas_access.dta.
*==================================================

clear all
set more off

if "${dir_proc}" == "" global dir_proc "C:\Users\USUARIO\OneDrive - Universidad de los andes\RA Andes - TIF\Datos\processed"
if "${dir_alex}" == "" global dir_alex "C:\Users\USUARIO\OneDrive - Universidad de los andes\RA Andes - TIF\Alex"
if "${dir_outcomes}" == "" global dir_outcomes "C:\Users\USUARIO\Documents\GitHub\TIF_PLMB\Datos\outcomes\paper"
capture mkdir "${dir_outcomes}"
capture log close
log using "${dir_outcomes}\ofertas_2025.log", text replace

import excel using "${dir_alex}\Ofertas_PH_CIB_2025.xlsx", ///
    sheet("OFERTAS_PH") firstrow clear
keep BARMANPRE VALOR_FINAL_VENTA VALOR_AVALUO_CAT ESTADO_ESTADISTICA ESTADO_SIE
capture confirm string variable BARMANPRE
if _rc tostring BARMANPRE, replace format(%012.0f)
destring VALOR_FINAL_VENTA VALOR_AVALUO_CAT, replace force
count
tab ESTADO_ESTADISTICA, missing
tab ESTADO_SIE, missing
keep if VALOR_FINAL_VENTA > 0 & VALOR_AVALUO_CAT > 0
keep if strlen(BARMANPRE) == 12
gen str9 mancodigo = substr(BARMANPRE, 1, 9)
gen double ln_oferta = ln(VALOR_FINAL_VENTA)
gen double ln_avaluo = ln(VALOR_AVALUO_CAT)
gen double razon = VALOR_FINAL_VENTA/VALOR_AVALUO_CAT

correlate ln_oferta ln_avaluo
correlate ln_oferta ln_avaluo if ESTADO_SIE == "VALIDA"
correlate ln_oferta ln_avaluo if ESTADO_ESTADISTICA == "Valida"
summarize razon, detail
merge m:1 mancodigo using "${dir_proc}\manzanas_access.dta", ///
    keep(master match) keepusing(dist_plmb) gen(m_dist)
tab m_dist
count if m_dist == 3 & dist_plmb <= 400
summarize razon if m_dist == 3 & dist_plmb <= 400, detail

log close
