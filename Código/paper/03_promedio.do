*==================================================
* 03_promedio.do
* Efecto promedio por buffer (400, 800 y 1200 m): DiD, event study con
* 2018 de referencia y sensibilidad de Rambachan y Roth.
* Oct 2026. 
* Requiere reghdfe y honestdid.
*==================================================

clear all
set more off
cap log close
log using "${dir_res}03_promedio.log", text replace
do "${dir_code}00_programas.do"
cap erase "${dir_res}honestdid_promedio.dta"

use "${dir_res}comun_lote_anio.dta", clear

*---------
* DiD por buffer
*---------

tempname pa
tempfile att
postfile `pa' int buffer str12 muestra double b se p li ls long n barrios using `att', replace
foreach b in 400 800 1200 {
    gen byte treat = post & treatment_`b' == 1
    reghdfe ln_avaluo_real_2014 treat [fw=n_registros], ///
        absorb(codigo_lote year) vce(cluster codigo_barrio) poolsize(1) compact
    estimates save "${dir_res}att_`b'.ster", replace
    quietly lincom treat
    post `pa' (`b') ("comun") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N)) (e(N_clust))

    ** Sin los lotes que salen de la muestra privada después de 2018
    reghdfe ln_avaluo_real_2014 treat if !sale [fw=n_registros], ///
        absorb(codigo_lote year) vce(cluster codigo_barrio) poolsize(1) compact
    quietly lincom treat
    post `pa' (`b') ("sin_salidas") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N)) (e(N_clust))
    drop treat
}
postclose `pa'
preserve
use `att', clear
gen double cambio_pct = 100 * (exp(b) - 1)
gen double cambio_li = 100 * (exp(li) - 1)
gen double cambio_ls = 100 * (exp(ls) - 1)
export delimited using "${dir_res}att.csv", replace
restore

*---------
* Event study y sensibilidad
*---------

tempname pp pc pr
tempfile pruebas coeficientes contrastes
postfile `pp' int buffer str15 prueba double F p long n barrios using `pruebas', replace
postfile `pc' int buffer year double b se p li ls using `coeficientes', replace
postfile `pr' int buffer str25 contraste double b se p li ls using `contrastes', replace

local previos "t2014 + t2015 + t2016 + t2017"
local posteriores "t2019 + t2020 + t2021 + t2022 + t2023 + t2024 + t2025"
foreach b in 400 800 1200 {
    local eventos
    foreach yy of numlist 2014/2017 2019/2025 {
        gen byte t`yy' = year == `yy' & treatment_`b' == 1
        local eventos `eventos' t`yy'
    }
    reghdfe ln_avaluo_real_2014 `eventos' [fw=n_registros], ///
        absorb(codigo_lote year) vce(cluster codigo_barrio) poolsize(1) compact
    estimates save "${dir_res}evento_`b'.ster", replace
    local n = e(N)
    local g = e(N_clust)

    test t2014 t2015 t2016 t2017
    post `pp' (`b') ("cero_previos") (r(F)) (r(p)) (`n') (`g')
    test (t2014 = t2015) (t2015 = t2016) (t2016 = t2017)
    post `pp' (`b') ("igualdad_previos") (r(F)) (r(p)) (`n') (`g')

    foreach yy of numlist 2014/2017 2019/2025 {
        quietly lincom t`yy'
        post `pc' (`b') (`yy') (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
    }

    ** Promedio posterior frente a 2018 y frente al promedio 2014-2018
    quietly lincom (`posteriores') / 7
    post `pr' (`b') ("post_vs_2018") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
    quietly lincom (`posteriores') / 7 - (`previos') / 5
    post `pr' (`b') ("post_vs_2014_2018") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))

    ** Rambachan y Roth sobre el promedio 2019-2025, en log puntos x 100.
    ** rm: cambios anuales acotados por M veces el mayor cambio previo.
    ** sd: cambios de pendiente acotados por M; M = 0 extrapola la tendencia lineal previa.
    hd_matrices `eventos', escala(100)
    #d ;
    hd_correr, pre(4) post(7) delta(rm) mvec(0 .25 .5 .75 1 1.5 2)
        archivo(honestdid_promedio) objetivo(att_`b');
    hd_correr, pre(4) post(7) delta(sd) mvec(0 .1 .2 .3 .5 1)
        archivo(honestdid_promedio) objetivo(att_`b');
    #d cr
    drop `eventos'
}
postclose `pp'
postclose `pc'
postclose `pr'

use `pruebas', clear
export delimited using "${dir_res}evento_pruebas.csv", replace
use `coeficientes', clear
export delimited using "${dir_res}evento_coef.csv", replace
use `contrastes', clear
export delimited using "${dir_res}evento_contrastes.csv", replace
use "${dir_res}honestdid_promedio.dta", clear
export delimited using "${dir_res}honestdid_promedio.csv", replace

log close
