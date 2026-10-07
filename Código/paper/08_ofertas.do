*==================================================
* 08_ofertas.do
* Ofertas de propiedad horizontal frente al avalúo catastral en 2025.
* Oct 2026. Correr desde 00_master.do. Usa Ofertas_PH_CIB_2025.xlsx de Álex.
*==================================================

clear all
set more off
cap log close
log using "${dir_res}08_ofertas.log", text replace

import excel using "${dir_alex}Ofertas_PH_CIB_2025.xlsx", sheet("OFERTAS_PH") firstrow clear
keep BARMANPRE VALOR_FINAL_VENTA VALOR_AVALUO_CAT
capture confirm string variable BARMANPRE
if _rc tostring BARMANPRE, replace format(%012.0f)
destring VALOR_FINAL_VENTA VALOR_AVALUO_CAT, replace force

** Precios positivos y código de predio completo, sin filtrar por estado
keep if VALOR_FINAL_VENTA > 0 & VALOR_AVALUO_CAT > 0 & strlen(BARMANPRE) == 12
gen str9 mancodigo = substr(BARMANPRE, 1, 9)
gen double ln_oferta = ln(VALOR_FINAL_VENTA)
gen double ln_avaluo = ln(VALOR_AVALUO_CAT)
gen double razon = VALOR_FINAL_VENTA / VALOR_AVALUO_CAT
merge m:1 mancodigo using "${dir_proc}manzanas_paper.dta", keep(master match) keepusing(dist_plmb) nogen

tempname po
tempfile ofertas
postfile `po' str10 grupo long n double r_log razon_mediana using `ofertas', replace
quietly correlate ln_oferta ln_avaluo
local r = r(rho)
quietly summarize razon, detail
post `po' ("todas") (r(N)) (`r') (r(p50))
quietly summarize razon if dist_plmb <= 400, detail
post `po' ("400m") (r(N)) (.) (r(p50))
postclose `po'
use `ofertas', clear
export delimited using "${dir_res}ofertas_2025.csv", replace

log close
