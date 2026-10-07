*==================================================
* 23_patron_previos.do
* Distinguir variación en 2014-2017 del contraste con 2018.
* 6 Oct 2026. Solo lee modelos guardados; no cambia el año de referencia.
* Igualdad entre cuatro coeficientes no demuestra tendencias paralelas.
*==================================================

clear all
set more off
args results_dir
if "`results_dir'" == "" local results_dir "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Paper/stata_results/diagnosticos_2026-10-06"
capture log close
log using "`results_dir'/patron_previos.log", text replace
tempfile pruebas promedios
tempname pp pc
postfile `pp' str18 familia str25 modelo int buffer double F p df df_r long n barrios using `pruebas', replace
postfile `pc' str18 familia str25 modelo int buffer double b se p li ls using `promedios', replace
foreach b in 400 800 1200 {
    foreach m in A_std economic_access ln_dist_cbd amenities_index ATT {
        local prefijo "tm"
        local archivo "previos_`b'_`m'"
        local familia "pendiente_M"
        if "`m'" == "ATT" {
            local prefijo "t"
            local archivo "dinamico_comun_`b'"
            local familia "ATT"
        }
        estimates use "`results_dir'/`archivo'.ster"
        quietly test (`prefijo'2014 = `prefijo'2015) (`prefijo'2015 = `prefijo'2016) (`prefijo'2016 = `prefijo'2017)
        post `pp' ("`familia'") ("`m'") (`b') (r(F)) (r(p)) (r(df)) (r(df_r)) (e(N)) (e(N_clust))
        quietly lincom (`prefijo'2014 + `prefijo'2015 + `prefijo'2016 + `prefijo'2017)/4
        post `pc' ("`familia'") ("`m'") (`b') (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
    }
}
estimates use "`results_dir'/cem_800_previos.ster"
quietly test (t2014 = t2015) (t2015 = t2016) (t2016 = t2017)
post `pp' ("CEM") ("ATT_ponderado") (800) (r(F)) (r(p)) (r(df)) (r(df_r)) (e(N)) (e(N_clust))
quietly lincom (t2014 + t2015 + t2016 + t2017)/4
post `pc' ("CEM") ("ATT_ponderado") (800) (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
estimates use "`results_dir'/terciles_conjunto.ster"
foreach grupo in inferior superior diferencia {
    local prefijo "g"
    local suma
    if "`grupo'" == "diferencia" local prefijo "dg"
    if "`grupo'" == "superior" local suma "dg"
    local igualdades
    local promedio
    foreach yy of numlist 2014/2017 {
        local termino "`prefijo'`yy'"
        if "`suma'" != "" local termino "`termino' + `suma'`yy'"
        if `yy' > 2014 local igualdades `igualdades' (`anterior' = `termino')
        if `yy' == 2014 local promedio "`termino'"
        else local promedio "`promedio' + `termino'"
        local anterior "`termino'"
    }
    quietly test `igualdades'
    post `pp' ("gradiente_tercil") ("`grupo'") (0) (r(F)) (r(p)) (r(df)) (r(df_r)) (e(N)) (e(N_clust))
    quietly lincom (`promedio')/4
    post `pc' ("gradiente_tercil") ("`grupo'") (0) (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
}
postclose `pp'
postclose `pc'
use `pruebas', clear
assert df == 3 & p >= 0 & p <= 1
export delimited using "`results_dir'/patron_previos_igualdad.csv", replace
use `promedios', clear
assert se > 0 & se < .
export delimited using "`results_dir'/patron_previos_promedio.csv", replace
log close
