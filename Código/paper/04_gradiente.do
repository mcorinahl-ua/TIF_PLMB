*==================================================
* 04_gradiente.do
* Cambio del gradiente de proximidad al trazado según
* la accesibilidad estructural A, con los demás moderadores.
* Oct 2026. 
* Requiere reghdfe y honestdid.
*
* Proximidad q = 1/(distancia + 1000). Los contrastes comparan 400 y 800 m.
* A queda en su escala de manzana (A = 0 es la media de manzanas).
*==================================================

clear all
set more off
cap log close
log using "${dir_res}04_gradiente.log", text replace
do "${dir_code}00_programas.do"
cap erase "${dir_res}honestdid_gradiente.dta"

use "${dir_res}comun_lote_anio.dta", clear

** Contraste 400 vs 800 m con offset de 1000 m
local d = 1/1400 - 1/1800

** Moderadores centrados en su media por registros. Los contrastes por
** "una DE" usan la DE entre manzanas, como A (que tiene DE 1 por manzana)
egen byte una_manzana = tag(mancodigo)
foreach v in ln_dist_cbd economic_access amenities_index {
    quietly summarize `v' if una_manzana
    local sd_`v' = r(sd)
    quietly summarize `v' [fw=n_registros]
    gen double `v'_c = `v' - r(mean)
}
drop una_manzana

** Interacciones con post
gen double post_q = post * prox1000
gen double post_a = post * A_std
gen double post_qa = post_q * A_std
gen double post_c = post * ln_dist_cbd_c
gen double post_qc = post_q * ln_dist_cbd_c
gen double post_e = post * economic_access_c
gen double post_qe = post_q * economic_access_c
gen double post_m = post * amenities_index_c
gen double post_qm = post_q * amenities_index_c

** Tramo del trazado (definido dentro de 800 m) y deciles de A
gen byte tramo = 0
replace tramo = tramo_800 if treatment_800 == 1 & !missing(tramo_800)
tab tramo treatment_800
xtile decil_A = A_std [fw=n_registros], nq(10)

*---------
* Modelos agrupados
*---------

** base: post x q, post x A y post x q x A
** cbd, todos: agregan los demás moderadores con su post x M y post x q x M
** tramo: cambios post y gradiente propios de cada tramo
** deciles: cambio citadino por decil de A en vez de lineal
** salidas: sin los lotes que salen de la muestra privada después de 2018
tempname pc pr
tempfile coeficientes contrastes
postfile `pc' str10 modelo str10 termino double b se p li ls long n barrios using `coeficientes', replace
postfile `pr' str10 modelo str12 contraste double b se p li ls using `contrastes', replace

foreach modelo in base cbd todos tramo deciles salidas {
    local a_term post_a
    local extra
    local si
    if "`modelo'" == "cbd" local extra post_c post_qc
    if "`modelo'" == "todos" local extra post_c post_qc post_e post_qe post_m post_qm
    if "`modelo'" == "tramo" local extra i.tramo#c.post i.tramo#c.post_q
    if "`modelo'" == "deciles" local a_term i(2/10).decil_A#c.post
    if "`modelo'" == "salidas" local si "if !sale"

    #d ;
    reghdfe ln_avaluo_real_2014 post_q `a_term' post_qa `extra' `si' [fw=n_registros],
        absorb(codigo_lote year) vce(cluster codigo_barrio)
        poolsize(1) compact;
    #d cr
    estimates save "${dir_res}gradiente_`modelo'.ster", replace
    local n = e(N)
    local g = e(N_clust)

    foreach v in post_q post_a post_qa post_c post_qc post_e post_qe post_m post_qm {
        capture lincom `v'
        if !_rc post `pc' ("`modelo'") ("`v'") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n') (`g')
    }

    ** Contraste 400 vs 800 m en A = 0 y A = 1 (log puntos). En tramo,
    ** post_q es el gradiente fuera de 800 m y solo se lee la interacción
    if "`modelo'" != "tramo" {
        forvalues a = 0/1 {
            quietly lincom `d' * (post_q + `a' * post_qa)
            post `pr' ("`modelo'") ("A`a'") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
        }
    }

    ** Cambio del contraste por una DE de cada moderador (log puntos)
    quietly lincom `d' * post_qa
    post `pr' ("`modelo'") ("sd_A") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
    if inlist("`modelo'", "cbd", "todos") {
        quietly lincom `d' * `sd_ln_dist_cbd' * post_qc
        post `pr' ("`modelo'") ("sd_cbd") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
    }
    if "`modelo'" == "todos" {
        quietly lincom `d' * `sd_economic_access' * post_qe
        post `pr' ("`modelo'") ("sd_empleo") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
        quietly lincom `d' * `sd_amenities_index' * post_qm
        post `pr' ("`modelo'") ("sd_equip") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
    }
}

** Offsets de 500 y 2000 m en el modelo base
foreach k in 500 2000 {
    gen double post_qk = post / (dist_plmb + `k')
    gen double post_qka = post_qk * A_std
    #d ;
    reghdfe ln_avaluo_real_2014 post_qk post_a post_qka [fw=n_registros],
        absorb(codigo_lote year) vce(cluster codigo_barrio)
        poolsize(1) compact;
    #d cr
    estimates save "${dir_res}gradiente_k`k'.ster", replace
    local n = e(N)
    local g = e(N_clust)
    foreach v in post_qk post_a post_qka {
        quietly lincom `v'
        local nombre = subinstr("`v'", "qk", "q", 1)
        post `pc' ("k`k'") ("`nombre'") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n') (`g')
    }
    local dk = 1/(400 + `k') - 1/(800 + `k')
    forvalues a = 0/1 {
        quietly lincom `dk' * (post_qk + `a' * post_qka)
        post `pr' ("k`k'") ("A`a'") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
    }
    drop post_qk post_qka
}
postclose `pc'
postclose `pr'

preserve
use `coeficientes', clear
export delimited using "${dir_res}gradiente_coef.csv", replace
use `contrastes', clear
gen double cambio_pct = 100 * (exp(b) - 1)
gen double cambio_li = 100 * (exp(li) - 1)
gen double cambio_ls = 100 * (exp(ls) - 1)
gen double logpuntos = 100 * b
export delimited using "${dir_res}gradiente_contrastes.csv", replace
restore

*---------
* Curva del contraste según A (figura 3)
*---------

estimates use "${dir_res}gradiente_base.ster"
tempname pq pk
tempfile percentiles curva
postfile `pq' byte percentil double A using `percentiles', replace
quietly _pctile A_std [fw=n_registros], p(1 5 10 25 50 75 90 95 99)
local j = 0
foreach p in 1 5 10 25 50 75 90 95 99 {
    local ++j
    local q`p' = r(r`j')
    post `pq' (`p') (`q`p'')
}
postclose `pq'
postfile `pk' double A b se li ls cambio_pct cambio_li cambio_ls using `curva', replace
forvalues j = 0/100 {
    local a = `q1' + (`q99' - `q1') * `j' / 100
    quietly lincom `d' * (post_q + `a' * post_qa)
    post `pk' (`a') (r(estimate)) (r(se)) (r(lb)) (r(ub)) ///
        (100 * (exp(r(estimate)) - 1)) (100 * (exp(r(lb)) - 1)) (100 * (exp(r(ub)) - 1))
}
postclose `pk'
preserve
use `percentiles', clear
export delimited using "${dir_res}A_percentiles.csv", replace
use `curva', clear
export delimited using "${dir_res}gradiente_curva.csv", replace
restore

*---------
* Modelos anuales
*---------

** anual: q, A y q x A por año, 2018 de referencia
** anual_cbd: agrega CBD y q x CBD por año
** q se multiplica por 1000 para la escala numérica; no cambia el modelo
keep codigo_lote codigo_barrio year ln_avaluo_real_2014 n_registros A_std prox1000 ln_dist_cbd_c A_tercil
gen double q = 1000 * prox1000
local dq = 1000 * `d'
local escala = 100 * `dq'

tempname pp pc pr
tempfile pruebas coeficientes contrastes
postfile `pp' str10 modelo str20 prueba double F p df df_r long n barrios using `pruebas', replace
postfile `pc' str10 modelo int year str3 familia double b se p li ls using `coeficientes', replace
postfile `pr' str10 modelo str3 familia str16 contraste double b se p li ls using `contrastes', replace

foreach modelo in anual anual_cbd {
    local familias q a qa
    if "`modelo'" == "anual_cbd" local familias q a c qa qc
    local eventos
    foreach yy of numlist 2014/2017 2019/2025 {
        gen double q`yy' = (year == `yy') * q
        gen double a`yy' = (year == `yy') * A_std
        gen double qa`yy' = q`yy' * A_std
        if "`modelo'" == "anual_cbd" {
            gen double c`yy' = (year == `yy') * ln_dist_cbd_c
            gen double qc`yy' = q`yy' * ln_dist_cbd_c
        }
        foreach f of local familias {
            local eventos `eventos' `f'`yy'
        }
    }
    #d ;
    reghdfe ln_avaluo_real_2014 `eventos' [fw=n_registros],
        absorb(codigo_lote year) vce(cluster codigo_barrio)
        poolsize(1) compact tolerance(1e-9);
    #d cr
    estimates save "${dir_res}gradiente_`modelo'.ster", replace
    local n = e(N)
    local g = e(N_clust)

    foreach f of local familias {
        test `f'2014 `f'2015 `f'2016 `f'2017
        post `pp' ("`modelo'") ("`f'_previos") (r(F)) (r(p)) (r(df)) (r(df_r)) (`n') (`g')
        test (`f'2014 = `f'2015) (`f'2015 = `f'2016) (`f'2016 = `f'2017)
        post `pp' ("`modelo'") ("`f'_igualdad") (r(F)) (r(p)) (r(df)) (r(df_r)) (`n') (`g')
        foreach yy of numlist 2014/2017 2019/2025 {
            quietly lincom `f'`yy'
            post `pc' ("`modelo'") (`yy') ("`f'") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
        }
        local previos "`f'2014 + `f'2015 + `f'2016 + `f'2017"
        local posteriores "`f'2019 + `f'2020 + `f'2021 + `f'2022 + `f'2023 + `f'2024 + `f'2025"
        quietly lincom (`previos') / 4
        post `pr' ("`modelo'") ("`f'") ("pre_2014_2017") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
        quietly lincom (`posteriores') / 7
        post `pr' ("`modelo'") ("`f'") ("post_vs_2018") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
        quietly lincom (`posteriores') / 7 - (`previos') / 5
        post `pr' ("`modelo'") ("`f'") ("post_vs_2014_2018") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
    }

    ** Rambachan y Roth en log puntos x 100 del contraste 400 vs 800 m.
    ** qa: por una DE de A; q: en A = 0. rm acota cambios anuales por M veces
    ** el mayor cambio previo; sd acota cambios de pendiente (M = 0 es lineal).
    local familias_hd qa
    if "`modelo'" == "anual" local familias_hd q qa
    foreach f of local familias_hd {
        local coef
        foreach yy of numlist 2014/2017 2019/2025 {
            local coef `coef' `f'`yy'
        }
        estimates use "${dir_res}gradiente_`modelo'.ster"
        hd_matrices `coef', escala(`escala')
        #d ;
        hd_correr, pre(4) post(7) delta(rm) mvec(0 .25 .5 .75 1 1.5 2)
            archivo(honestdid_gradiente) objetivo(`modelo'_`f'_ref2018);
        hd_correr, pre(4) post(7) delta(sd) mvec(0 .05 .1 .2 .3 .5)
            archivo(honestdid_gradiente) objetivo(`modelo'_`f'_ref2018);
        #d cr

        ** 2017 de referencia y 2018 como año de transición, fuera del promedio
        hd_ref2017
        #d ;
        hd_correr, pre(3) post(8) omitir(1) delta(rm) mvec(0 .25 .5 .75 1 1.5 2)
            archivo(honestdid_gradiente) objetivo(`modelo'_`f'_ref2017);
        #d cr
    }
    drop `eventos'
}
postclose `pp'
postclose `pc'
postclose `pr'

preserve
use `pruebas', clear
export delimited using "${dir_res}gradiente_anual_pruebas.csv", replace
use `coeficientes', clear
gen double logpuntos = 100 * `dq' * b
gen double logpuntos_li = 100 * `dq' * li
gen double logpuntos_ls = 100 * `dq' * ls
export delimited using "${dir_res}gradiente_anual_coef.csv", replace
use `contrastes', clear
gen double logpuntos = 100 * `dq' * b
gen double logpuntos_li = 100 * `dq' * li
gen double logpuntos_ls = 100 * `dq' * ls
export delimited using "${dir_res}gradiente_anual_contrastes.csv", replace
use "${dir_res}honestdid_gradiente.dta", clear
export delimited using "${dir_res}honestdid_gradiente.csv", replace
restore

*---------
* Gradientes de los terciles extremos de A
*---------

** Un solo modelo con FE de lote y de tercil x año, para comparar
** directamente los dos gradientes con su covarianza
keep if inlist(A_tercil, 1, 3)
gen byte alto = A_tercil == 3
local eventos
local diferencias_previas
foreach yy of numlist 2014/2017 2019/2025 {
    gen double g`yy' = (year == `yy') * prox1000
    gen double dg`yy' = g`yy' * alto
    local eventos `eventos' g`yy' dg`yy'
    if `yy' < 2018 local diferencias_previas `diferencias_previas' dg`yy'
}
#d ;
reghdfe ln_avaluo_real_2014 `eventos' [fw=n_registros],
    absorb(codigo_lote alto#year) vce(cluster codigo_barrio)
    poolsize(1) compact;
#d cr
estimates save "${dir_res}terciles.ster", replace
local n = e(N)
local g = e(N_clust)

tempname pp pc
tempfile pruebas coeficientes
postfile `pp' str20 prueba double F p long n barrios using `pruebas', replace
test g2014 g2015 g2016 g2017
post `pp' ("tercil_inferior") (r(F)) (r(p)) (`n') (`g')
test (g2014 + dg2014 = 0) (g2015 + dg2015 = 0) (g2016 + dg2016 = 0) (g2017 + dg2017 = 0)
post `pp' ("tercil_superior") (r(F)) (r(p)) (`n') (`g')
test `diferencias_previas'
post `pp' ("diferencia_terciles") (r(F)) (r(p)) (`n') (`g')
postclose `pp'

postfile `pc' int year str10 termino double b se p li ls using `coeficientes', replace
foreach yy of numlist 2014/2017 2019/2025 {
    quietly lincom g`yy'
    post `pc' (`yy') ("inferior") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
    quietly lincom g`yy' + dg`yy'
    post `pc' (`yy') ("superior") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
    quietly lincom dg`yy'
    post `pc' (`yy') ("diferencia") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
}
postclose `pc'

use `pruebas', clear
export delimited using "${dir_res}terciles_pruebas.csv", replace
use `coeficientes', clear
gen double premio = 100 * (exp(`d' * b) - 1)
gen double premio_li = 100 * (exp(`d' * li) - 1)
gen double premio_ls = 100 * (exp(`d' * ls) - 1)
gen double contraste_log = 100 * `d' * b
gen double contraste_li = 100 * `d' * li
gen double contraste_ls = 100 * `d' * ls
export delimited using "${dir_res}terciles_coef.csv", replace

log close
