*==================================================
* 26_gradiente_cem.do
* Contraste central de accesibilidad con los pesos CEM guardados.
* 7 Oct 2026. Diagnóstico de la cohorte de 800 m, sin nuevo matching.
* Requiere reghdfe. Conserva los registros y pesos originales.
*==================================================

clear all
set more off
args results_dir
if "${dir_proc}" == "" global dir_proc "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Datos/processed"
if "`results_dir'" == "" local results_dir "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Paper/stata_results/diagnosticos_2026-10-06"
capture log close
log using "`results_dir'/cem_gradiente.log", text replace
confirm file "`results_dir'/cem_verificado.txt"

* Misma selección y llaves del 17; aquí se conserva la accesibilidad.
#d ;
use codigo_lote codigo_construccion codigo_resto year codigo_barrio
    c_barrio c_manzana descripcion_destino ln_avaluo_real_2014 treatment_800
    using "${dir_proc}/predios_robust.dta", clear;
#d cr
keep if !inlist(descripcion_destino, "VIAS", "ESPACIO PÚBLICO", ///
    "LOTE DEL ESTADO", "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO") & !missing(ln_avaluo_real_2014)
drop descripcion_destino
gen str9 mancodigo = c_barrio + "0" + c_manzana
drop c_barrio c_manzana
#d ;
merge m:1 mancodigo using "${dir_proc}/manzanas_access.dta",
    keep(master match) keepusing(dist_plmb A_std A_rank
    economic_access ln_dist_cbd amenities_index);
#d cr
keep if !missing(dist_plmb, A_std, A_rank, economic_access, ln_dist_cbd, amenities_index) & dist_plmb >= 0
drop _merge mancodigo A_rank economic_access ln_dist_cbd amenities_index
merge m:1 codigo_lote codigo_construccion codigo_resto ///
    using "`results_dir'/cem_pesos_verificados.dta", keep(master match)
assert treatment_800 == treatment_800_2018 if _merge == 3
keep if _merge == 3
assert !missing(cem_weights) & cem_weights > 0
drop _merge treatment_800_2018 codigo_construccion codigo_resto

gen double q = 1000/(dist_plmb + 1000)
gen double post_q = (year >= 2019)*q
gen double post_a = (year >= 2019)*A_std
gen double post_qa = post_q*A_std
#d ;
reghdfe ln_avaluo_real_2014 post_q post_a post_qa [aw=cem_weights],
    absorb(codigo_lote year) vce(cluster codigo_barrio)
    poolsize(1) compact tolerance(1e-9);
#d cr
assert e(N_clust) > 1 & e(converged) == 1
estimates save "`results_dir'/cem_gradiente.ster", replace
local n = e(N)
local g = e(N_clust)
tempfile coef contrastes
tempname pc pr
postfile `pc' str12 termino double b se p li ls long n barrios using `coef', replace
foreach v in post_q post_a post_qa {
    quietly lincom `v'
    assert r(se) > 0 & r(se) < .
    post `pc' ("`v'") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n') (`g')
}
postclose `pc'
local delta = 1000*(1/1400 - 1/1800)
postfile `pr' double a b se p li ls long n barrios using `contrastes', replace
foreach a in 0 1 {
    quietly lincom `delta'*(post_q + `a'*post_qa)
    post `pr' (`a') (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n') (`g')
}
postclose `pr'
use `coef', clear
export delimited using "`results_dir'/cem_gradiente_coef.csv", replace
use `contrastes', clear
gen double cambio_pct = 100*(exp(b)-1)
gen double cambio_li = 100*(exp(li)-1)
gen double cambio_ls = 100*(exp(ls)-1)
export delimited using "`results_dir'/cem_gradiente_contrastes.csv", replace
log close
