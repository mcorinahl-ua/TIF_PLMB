*==================================================
* 21_descriptivos_paper.do
* Descriptivos de 2018 para la muestra común y los tres buffers.
* 6 Oct 2026. Medias y DE sobre registros, antes de singletons.
* El estrato se describe solo entre residenciales clasificados 1-6.
*==================================================

clear all
set more off
args results_dir
if "${dir_proc}" == "" global dir_proc "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Datos/processed"
if "`results_dir'" == "" local results_dir "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Paper/stata_results/diagnosticos_2026-10-06"
capture log close
log using "`results_dir'/descriptivos_2018.log", text replace
import delimited using "`results_dir'/cobertura_muestra.csv", clear
quietly summarize registros_comunes if year == 2018
local n_esperado = r(mean)
#d;
use codigo_lote codigo_barrio c_barrio c_manzana year
    ln_avaluo_real_2014 avaluo_real_2014 descripcion_destino
    area_construida area_terreno codigo_estrato max_num_piso
    treatment_400 treatment_800 treatment_1200
    if year == 2018 using "${dir_proc}/predios_robust.dta", clear;
#d cr
keep if !inlist(descripcion_destino, "VIAS", "ESPACIO PÚBLICO", ///
    "LOTE DEL ESTADO", "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO")
keep if !missing(ln_avaluo_real_2014)
assert strlen(c_barrio) == 6 & strlen(c_manzana) == 2
gen str9 mancodigo = c_barrio + "0" + c_manzana
#d;
merge m:1 mancodigo using "${dir_proc}/manzanas_access.dta",
    keep(master match) keepusing(dist_plmb A_std A_rank
    economic_access ln_dist_cbd amenities_index);
#d cr
keep if !missing(dist_plmb, A_std, A_rank, economic_access, ln_dist_cbd, amenities_index) & dist_plmb >= 0
assert _N == `n_esperado'
gen double avaluo_millones = avaluo_real_2014/1000000
gen byte estrato_res = codigo_estrato if descripcion_destino == "RESIDENCIAL" & inrange(codigo_estrato, 1, 6)
tempfile descriptivos soporte
tempname pd ps
postfile `pd' int buffer byte tratado str25 variable long n double media sd using `descriptivos', replace
postfile `ps' int buffer byte tratado long registros lotes barrios using `soporte', replace
foreach b in 400 800 1200 {
    assert inlist(treatment_`b', 0, 1)
    egen byte tag_lote = tag(treatment_`b' codigo_lote)
    egen byte tag_barrio = tag(treatment_`b' codigo_barrio)
    forvalues t = 0/1 {
        quietly count if treatment_`b' == `t'
        local n = r(N)
        quietly count if treatment_`b' == `t' & tag_lote
        local nl = r(N)
        quietly count if treatment_`b' == `t' & tag_barrio
        post `ps' (`b') (`t') (`n') (`nl') (r(N))
        foreach v in ln_avaluo_real_2014 avaluo_millones area_construida area_terreno ///
            estrato_res max_num_piso A_std economic_access ln_dist_cbd amenities_index {
            quietly summarize `v' if treatment_`b' == `t'
            post `pd' (`b') (`t') ("`v'") (r(N)) (r(mean)) (r(sd))
        }
    }
    drop tag_lote tag_barrio
}
postclose `pd'
postclose `ps'
use `descriptivos', clear
export delimited using "`results_dir'/descriptivos_2018.csv", replace
use `soporte', clear
export delimited using "`results_dir'/descriptivos_2018_soporte.csv", replace
log close
