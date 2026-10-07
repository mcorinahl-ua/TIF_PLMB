*==================================================
* 13_pretrends_buffers.do
* Dinámica del ATT para los tres buffers, con 2018 como referencia.
* 2 Oct 2026. Requiere reghdfe y predios_robust.dta.
*==================================================

clear all
set more off
args results_dir
if "${dir_proc}" == "" global dir_proc "C:\Users\USUARIO\OneDrive - Universidad de los andes\RA Andes - TIF\Datos\processed"
if "`results_dir'" == "" local results_dir "C:\Users\USUARIO\Documents\GitHub\TIF_PLMB\Datos\outcomes\paper"
capture mkdir "`results_dir'"
capture log close
log using "`results_dir'\pretrends_buffers.log", text replace

use codigo_lote year codigo_barrio descripcion_destino ln_avaluo_real_2014 ///
    treatment_400 treatment_800 treatment_1200 ///
    using "${dir_proc}\predios_robust.dta", clear
gen byte privado = !inlist(descripcion_destino, "VIAS", "ESPACIO PÚBLICO", ///
    "LOTE DEL ESTADO", "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO")
keep if privado & !missing(ln_avaluo_real_2014)

tempfile coeficientes pruebas
tempname pc pp
postfile `pc' int buffer year double b se long n using `coeficientes', replace
postfile `pp' int buffer double F p long n using `pruebas', replace

foreach b in 400 800 1200 {
    assert inlist(treatment_`b', 0, 1)
    bysort codigo_lote: egen byte tmin = min(treatment_`b')
    by codigo_lote: egen byte tmax = max(treatment_`b')
    count if tmin != tmax
    if r(N) > 0 {
        display as error "El tratamiento del buffer `b' cambia dentro del lote."
        exit 459
    }
    drop tmin tmax

    local eventos
    foreach yy of numlist 2014/2017 2019/2025 {
        gen byte e`b'_`yy' = (year == `yy' & treatment_`b' == 1)
        local eventos `eventos' e`b'_`yy'
    }
    reghdfe ln_avaluo_real_2014 `eventos', ///
        absorb(codigo_lote year) vce(cluster codigo_barrio)
    local n = e(N)
    estimates save "`results_dir'\pretrends_buffer_`b'.ster", replace
    test e`b'_2014 e`b'_2015 e`b'_2016 e`b'_2017
    post `pp' (`b') (r(F)) (r(p)) (`n')
    foreach yy of numlist 2014/2017 2019/2025 {
        post `pc' (`b') (`yy') (_b[e`b'_`yy']) (_se[e`b'_`yy']) (`n')
    }
    drop `eventos'
}

postclose `pc'
postclose `pp'
use `coeficientes', clear
export delimited using "`results_dir'\pretrends_buffers_coef.csv", replace
use `pruebas', clear
export delimited using "`results_dir'\pretrends_buffers_test.csv", replace
log close
