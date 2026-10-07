*==================================================
* 22_sensibilidad_gradiente.do
* Sensibilidad a offsets de 500 y 2000 m sobre la muestra común.
* 6 Oct 2026. Reutiliza el modelo de 1000 m; FE lote y año, cluster barrio.
* Cambia solo el offset. No corrige las diferencias de tendencias previas.
*==================================================

clear all
set more off
args results_dir
if "`results_dir'" == "" local results_dir "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Paper/stata_results/diagnosticos_2026-10-06"
capture log close
log using "`results_dir'/sensibilidad_gradiente.log", text replace
confirm file "`results_dir'/agrupacion_verificada.txt"
#d;
use codigo_lote codigo_barrio year ln_avaluo_real_2014
    n_registros A_std dist_plmb post
    using "`results_dir'/comun_lote_anio.dta", clear;
#d cr
gen double prox = .
tempfile coeficientes contrastes
tempname pc pr
#d;
postfile `pc' int offset str25 termino double b se p li ls
    long n barrios using `coeficientes', replace;
postfile `pr' int offset byte A double b se p li ls cambio_pct cambio_li cambio_ls
    long n barrios using `contrastes', replace;
#d cr
foreach k in 500 1000 2000 {
    local var "prox"
    if `k' == 1000 {
        estimates use "`results_dir'/gradiente_comun_A_std.ster"
        local var "prox1000"
    }
    else {
        replace prox = 1/(dist_plmb + `k')
        #d;
        reghdfe ln_avaluo_real_2014 c.post#c.prox c.post#c.A_std
            c.post#c.prox#c.A_std [fw=n_registros],
            absorb(codigo_lote year) vce(cluster codigo_barrio)
            poolsize(1) compact;
        #d cr
        estimates save "`results_dir'/gradiente_comun_A_std_k`k'.ster", replace
    }
    assert e(N) == 25334749 & e(N_clust) == 952
    foreach termino in c.post#c.`var' c.post#c.A_std c.post#c.`var'#c.A_std {
        quietly lincom `termino'
        post `pc' (`k') ("`termino'") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N)) (e(N_clust))
    }
    local delta = 1/(400+`k') - 1/(800+`k')
    forvalues a = 0/1 {
        quietly lincom `delta' * (c.post#c.`var' + `a' * c.post#c.`var'#c.A_std)
        post `pr' (`k') (`a') (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) ///
            (100*(exp(r(estimate))-1)) (100*(exp(r(lb))-1)) (100*(exp(r(ub))-1)) (e(N)) (e(N_clust))
    }
}
postclose `pc'
postclose `pr'
use `coeficientes', clear
export delimited using "`results_dir'/sensibilidad_gradiente_coef.csv", replace
use `contrastes', clear
export delimited using "`results_dir'/sensibilidad_gradiente_contrastes.csv", replace
log close
