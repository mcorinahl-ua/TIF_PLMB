*==================================================
* 24_gradiente_temporal.do
* Evolución anual del gradiente continuo y su interacción con A_std.
* 6 Oct 2026. Misma muestra común, FE lote/año y cluster barrio.
* Requiere reghdfe. Referencia: 2018. q se multiplica por 1000
* para mejorar la escala numérica; no cambia el modelo ni los contrastes.
*==================================================

clear all
set more off
args results_dir etapa
if "`results_dir'" == "" local results_dir "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Paper/stata_results/diagnosticos_2026-10-06"
if "`etapa'" == "" local etapa "estimar"
assert inlist("`etapa'", "estimar", "resultados")
capture log close
log using "`results_dir'/gradiente_temporal_`etapa'.log", text replace
confirm file "`results_dir'/agrupacion_verificada.txt"

if "`etapa'" == "estimar" {
    #d ;
    use codigo_lote codigo_barrio year ln_avaluo_real_2014
        n_registros A_std prox1000
        using "`results_dir'/comun_lote_anio.dta", clear;
    #d cr
    assert !missing(A_std, prox1000, ln_avaluo_real_2014, n_registros)
    gen double q = 1000*prox1000
    local eventos
    foreach yy of numlist 2014/2017 2019/2025 {
        gen double q`yy' = (year == `yy')*q
        gen double a`yy' = (year == `yy')*A_std
        gen double qa`yy' = q`yy'*A_std
        local eventos `eventos' q`yy' a`yy' qa`yy'
    }
    #d ;
    reghdfe ln_avaluo_real_2014 `eventos' [fw=n_registros],
        absorb(codigo_lote year) vce(cluster codigo_barrio)
        poolsize(1) compact tolerance(1e-9);
    #d cr
    assert e(N) == 25334749 & e(N_clust) == 952
    assert e(df_r) == 951
    estimates save "`results_dir'/gradiente_temporal_comun.ster", replace
}
else estimates use "`results_dir'/gradiente_temporal_comun.ster"

*---------
* Pruebas previas y contrastes con su covarianza conjunta
*---------

local n = e(N)
local g = e(N_clust)
local delta = 1000*(1/1400 - 1/1800)
tempfile pruebas coeficientes contrastes
tempname pp pc pr
#d ;
postfile `pp' str30 prueba double F p df df_r
    long n barrios using `pruebas', replace;
postfile `pc' int year str8 familia double b se p li ls
    long n barrios using `coeficientes', replace;
postfile `pr' str35 contraste double b se p li ls
    logpuntos_400_800 li_400_800 ls_400_800 using `contrastes', replace;
#d cr
foreach prefijo in q a qa {
    test `prefijo'2014 `prefijo'2015 `prefijo'2016 `prefijo'2017
    assert r(df) == 4
    post `pp' ("`prefijo'_previos") (r(F)) (r(p)) (r(df)) (r(df_r)) (`n') (`g')
}
test q2014 q2015 q2016 q2017 a2014 a2015 a2016 a2017 qa2014 qa2015 qa2016 qa2017
post `pp' ("conjunta_previos") (r(F)) (r(p)) (r(df)) (r(df_r)) (`n') (`g')
test (qa2014 = qa2015) (qa2015 = qa2016) (qa2016 = qa2017)
post `pp' ("qa_igualdad_2014_2017") (r(F)) (r(p)) (r(df)) (r(df_r)) (`n') (`g')
foreach yy of numlist 2014/2017 2019/2025 {
    foreach prefijo in q a qa {
        quietly lincom `prefijo'`yy'
        assert r(se) > 0 & r(se) < .
        post `pc' (`yy') ("`prefijo'") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n') (`g')
    }
}
local pre "qa2014 + qa2015 + qa2016 + qa2017"
local posterior "qa2019 + qa2020 + qa2021 + qa2022 + qa2023 + qa2024 + qa2025"
foreach contraste in pre_2014_2017 post_2019_2025 cambio_post_pre {
    if "`contraste'" == "pre_2014_2017" local expresion "(`pre')/4"
    if "`contraste'" == "post_2019_2025" local expresion "(`posterior')/7"
    if "`contraste'" == "cambio_post_pre" local expresion "(`posterior')/7 - (`pre')/5"
    quietly lincom `expresion'
    post `pr' ("`contraste'") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) ///
        (100*`delta'*r(estimate)) (100*`delta'*r(lb)) (100*`delta'*r(ub))
}
postclose `pp'
postclose `pc'
postclose `pr'
use `pruebas', clear
assert inrange(p, 0, 1)
export delimited using "`results_dir'/gradiente_temporal_test.csv", replace
use `contrastes', clear
assert se > 0 & se < .
export delimited using "`results_dir'/gradiente_temporal_contrastes.csv", replace
use `coeficientes', clear
assert se > 0 & se < .
export delimited using "`results_dir'/gradiente_temporal_coef.csv", replace

*---------
* Cambio del contraste 400 vs 800 m por una desviación estándar de A
*---------

keep if familia == "qa"
gen double estimacion = 100*`delta'*b
gen double inferior = 100*`delta'*li
gen double superior = 100*`delta'*ls
local nueva = _N + 1
set obs `nueva'
replace year = 2018 in `nueva'
foreach v in estimacion inferior superior {
    replace `v' = 0 in `nueva'
}
sort year
#d ;
twoway (rcap inferior superior year, lcolor(navy))
    (connected estimacion year, lcolor(navy) mcolor(navy) msymbol(O)),
    yline(0, lcolor(gs10)) xline(2018.5, lcolor(gs10) lpattern(dash))
    xlabel(2014(1)2025, angle(45))
    xtitle("Year")
    ytitle("Change in accessibility contrast (log points x 100)")
    legend(off) graphregion(color(white));
#d cr
graph export "`results_dir'/gradiente_temporal_interaccion.png", replace width(1800)
log close
