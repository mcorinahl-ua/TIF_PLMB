*==================================================
* 20_figura_gradiente.do
* Figura del contraste de 400 frente a 800 m con el modelo guardado.
* 6 Oct 2026. No reestima; usa la muestra común de 14_diagnosticos_paper.do.
* Los intervalos usan la covarianza conjunta de los dos coeficientes.
*==================================================

clear all
set more off
args results_dir
if "`results_dir'" == "" local results_dir "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Paper/stata_results/diagnosticos_2026-10-06"
capture log close
log using "`results_dir'/figura_gradiente.log", text replace
confirm file "`results_dir'/agrupacion_verificada.txt"
use codigo_lote A_std n_registros using "`results_dir'/comun_lote_anio.dta", clear
bys codigo_lote: egen long registros_lote = total(n_registros)
drop if registros_lote == 1
quietly summarize n_registros
local n = r(sum)
assert `n' == 25334749
tempfile percentiles curva
tempname pq pr
postfile `pq' byte percentil double A using `percentiles', replace
quietly _pctile A_std [fw=n_registros], p(1 5 10 25 50 75 90 95 99)
local j = 0
foreach p in 1 5 10 25 50 75 90 95 99 {
    local ++j
    local q`p' = r(r`j')
    post `pq' (`p') (`q`p'')
}
postclose `pq'
estimates use "`results_dir'/gradiente_comun_A_std.ster"
assert e(N) == `n' & e(N_clust) == 952
local delta = 1/1400 - 1/1800
#d;
postfile `pr' double A b se p li ls cambio_pct cambio_li cambio_ls
    using `curva', replace;
#d cr
forvalues j = 0/100 {
    local a = `q1' + (`q99' - `q1') * `j'/100
    quietly lincom `delta' * (c.post#c.prox1000 + `a' * c.post#c.prox1000#c.A_std)
    post `pr' (`a') (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) ///
        (100*(exp(r(estimate))-1)) (100*(exp(r(lb))-1)) (100*(exp(r(ub))-1))
}
postclose `pr'
use `percentiles', clear
export delimited using "`results_dir'/A_percentiles_comun.csv", replace
use `curva', clear
export delimited using "`results_dir'/gradiente_curva_comun.csv", replace
#d;
twoway (rarea cambio_li cambio_ls A, fcolor(gs13) fintensity(100) lcolor(gs13))
    (line cambio_li cambio_ls A, lcolor(gs9 gs9) lwidth(vthin vthin))
    (line cambio_pct A, lcolor(navy) lwidth(medthick)),
    yline(0, lcolor(gs8) lpattern(dash))
    xline(0, lcolor(gs10) lpattern(shortdash))
    xtitle("Structural accessibility A (standard deviations)")
    ytitle("Post-period change in the proximity contrast (%)")
    xlabel(, labsize(medium)) ylabel(, angle(horizontal) labsize(medium))
    note("400 m versus 800 m. Post period: 2019-2025. 95% confidence interval."
         "Curve shown between the 1st and 99th percentiles of the common record sample.", size(small))
    legend(off) graphregion(color(white)) plotregion(color(white));
#d cr
graph export "`results_dir'/gradiente_curva_comun.png", width(1800) replace
log close
