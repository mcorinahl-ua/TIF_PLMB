*==================================================
* 10_paper.do
* Resultados del paper PLMB: panel 2014-2025, post desde 2019
* y 2018 como referencia de los modelos dinámicos.
* 1 Oct 2026. Requiere reghdfe y la base de 7_centralidades.do
* con A_std y A_rank.
*==================================================

clear all
set more off
args results_dir main_only moderation_only buffers_only

* Se pueden definir estas rutas antes de llamar el do-file.
if "${dir_proc}" == "" global dir_proc "C:\Users\USUARIO\OneDrive - Universidad de los andes\RA Andes - TIF\Datos\processed"
if "${dir_outcomes}" == "" global dir_outcomes "C:\Users\USUARIO\Documents\GitHub\TIF_PLMB\Datos\outcomes\paper"
if "`results_dir'" != "" global dir_outcomes "`results_dir'"
capture mkdir "${dir_outcomes}"
capture log close
if "`buffers_only'" == "1" log using "${dir_outcomes}\paper_buffers.log", text replace
else log using "${dir_outcomes}\paper_stata.log", text replace

*---------
* Panel y variables del paper
*---------

if "`buffers_only'" != "1" {
if "`moderation_only'" == "1" {
    use codigo_lote codigo_construccion codigo_resto year codigo_barrio ///
        mancodigo treatment treat ln_avaluo_real_2014 ///
        using "${dir_proc}\predios_proc_ai2.dta", clear
}
else {
    use codigo_lote codigo_construccion codigo_resto year codigo_barrio ///
        mancodigo treatment treat ln_avaluo_real_2014 ln_avaluo_com_2014 ///
        avaluo_real_2014 descripcion_destino area_construida area_terreno ///
        codigo_estrato max_num_piso ///
        using "${dir_proc}\predios_proc_ai2.dta", clear
}

* Construcción y resto identifican filas; los efectos fijos se definen por lote.
isid codigo_lote codigo_construccion codigo_resto year
assert inrange(year, 2014, 2025)
bys codigo_lote codigo_construccion codigo_resto: gen byte n_anios = _N
by codigo_lote codigo_construccion codigo_resto: gen byte tag_unidad = _n == 1
count if tag_unidad & n_anios != 12
display "Identificadores de construcción/resto con menos de 12 años: " r(N)
by codigo_lote codigo_construccion codigo_resto: gen byte cambio_trat = treatment != treatment[1]
count if cambio_trat
if r(N) > 0 {
    display as error "La asignación al área de influencia cambia dentro de una unidad catastral."
    exit 459
}
drop n_anios tag_unidad cambio_trat codigo_construccion codigo_resto

bysort codigo_lote year: gen byte tag_lote_anio = _n == 1
bysort codigo_lote: egen byte n_anios_lote = total(tag_lote_anio)
by codigo_lote: gen byte tag_lote = _n == 1
count if tag_lote & n_anios_lote < 12
display "Lotes con menos de 12 años: " r(N)
drop tag_lote_anio n_anios_lote tag_lote

if "`moderation_only'" == "1" {
    merge m:1 mancodigo using "${dir_proc}\manzanas_access.dta", ///
        keep(master match) nogen ///
        keepusing(economic_access economic_access_gr economic_access_exp ///
                  access_group ln_dist_cbd cbd_group amenities_index A_std)
}
else {
    merge m:1 mancodigo using "${dir_proc}\manzanas_access.dta", ///
        keep(master match) nogen ///
        keepusing(dist_plmb economic_access economic_access_gr economic_access_exp ///
                  access_group ln_dist_cbd cbd_group amenities_index I_AccB A_std A_rank)
}

confirm variable A_std
if "`moderation_only'" != "1" confirm variable A_rank
assert treat == (treatment == 1 & year >= 2019) if !missing(treatment)
bys codigo_lote: egen byte tmin = min(treatment)
bys codigo_lote: egen byte tmax = max(treatment)
egen byte tag_lote = tag(codigo_lote)
count if tag_lote & tmin != tmax
if r(N) > 0 {
    display as error "La asignación al área de influencia cambia dentro de un lote. Revisar 6_nueva_ai.do."
    exit 459
}
drop tmin tmax tag_lote
gen byte post = year >= 2019
if "`moderation_only'" != "1" {
gen byte privado = !inlist(descripcion_destino, "VIAS", "ESPACIO PÚBLICO", ///
    "LOTE DEL ESTADO", "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO")
gen double prox1000 = 1/(dist_plmb + 1000) if dist_plmb >= 0

* Tabla 1: descriptivos 2014-2018. Estrato 0 es sin clasificar.
gen double aval_mm = avaluo_real_2014/1e6
gen estrato_desc = codigo_estrato if codigo_estrato != 0
tabstat ln_avaluo_real_2014 aval_mm area_construida area_terreno ///
    estrato_desc max_num_piso if year <= 2018 & privado, ///
    by(treatment) statistics(n mean sd) columns(statistics)

* Comparación con el avalúo comercial de referencia.
correlate ln_avaluo_real_2014 ln_avaluo_com_2014
forvalues yy = 2014/2025 {
    correlate ln_avaluo_real_2014 ln_avaluo_com_2014 if year == `yy'
}

*---------
* Efecto promedio y gradiente (tablas 3 y 4)
*---------

reghdfe ln_avaluo_real_2014 treat if privado, ///
    absorb(codigo_lote year) vce(cluster codigo_barrio)
estimates store ai_base
estimates save "${dir_outcomes}\ai_base.ster", replace

* Dinámica del efecto promedio; 2018 es el año omitido.
local ai_years
foreach yy of numlist 2014/2017 2019/2025 {
    gen byte ai_`yy' = (year == `yy' & treatment == 1)
    local ai_years `ai_years' ai_`yy'
}
reghdfe ln_avaluo_real_2014 `ai_years' if privado, ///
    absorb(codigo_lote year) vce(cluster codigo_barrio)
estimates store ai_dinamico
estimates save "${dir_outcomes}\ai_dinamico.ster", replace
test ai_2014 ai_2015 ai_2016 ai_2017
drop `ai_years'

reghdfe ln_avaluo_real_2014 c.post#c.prox1000, ///
    absorb(codigo_lote year) vce(cluster codigo_barrio)
estimates store gradiente
estimates save "${dir_outcomes}\gradiente.ster", replace

#d;
reghdfe ln_avaluo_real_2014
    c.post#c.prox1000 c.post#c.A_std
    c.post#c.prox1000#c.A_std,
    absorb(codigo_lote year) vce(cluster codigo_barrio);
#d cr
estimates store triple
estimates save "${dir_outcomes}\triple.ster", replace

* Figura 3: premio implícito de 400 m frente a 800 m.
local delta = 1/1400 - 1/1800
scalar b_prox = _b[c.post#c.prox1000]
scalar b_triple = _b[c.post#c.prox1000#c.A_std]
matrix V = e(V)
local i = colnumb(V, "c.post#c.prox1000")
local j = colnumb(V, "c.post#c.prox1000#c.A_std")
scalar v_prox = V[`i',`i']
scalar v_cross = V[`i',`j']
scalar v_triple = V[`j',`j']
quietly summarize A_std if e(sample), detail
local a_lo = r(p1)
local a_hi = r(p99)
preserve
clear
set obs 101
gen double A = `a_lo' + (_n-1)*(`a_hi'-`a_lo')/100
gen double log_premio = `delta'*(b_prox + b_triple*A)
gen double premio = 100*(exp(log_premio)-1)
gen double se = 100*exp(log_premio)*`delta'* ///
    sqrt(v_prox + 2*A*v_cross + A^2*v_triple)
gen double li = premio - 1.96*se
gen double ls = premio + 1.96*se
twoway (rarea ls li A, color(gs13)) (line premio A, lcolor(navy)), ///
    yline(0, lpattern(dash) lcolor(gs8)) ///
    xtitle("Accesibilidad estructural A (desviaciones estándar)") ///
    ytitle("Premio de 400 m frente a 800 m (%)") legend(off)
graph export "${dir_outcomes}\fig_marginal_gradient.pdf", replace
restore

* Rango percentil y distancia inversa con otros desplazamientos (tabla 8).
#d;
reghdfe ln_avaluo_real_2014
    c.post#c.prox1000 c.post#c.A_rank
    c.post#c.prox1000#c.A_rank,
    absorb(codigo_lote year) vce(cluster codigo_barrio);
#d cr
estimates store triple_rank
estimates save "${dir_outcomes}\triple_rank.ster", replace

foreach offset in 500 2000 {
    gen double prox`offset' = 1/(dist_plmb + `offset') if dist_plmb >= 0
    #d;
    reghdfe ln_avaluo_real_2014
        c.post#c.prox`offset' c.post#c.A_std
        c.post#c.prox`offset'#c.A_std,
        absorb(codigo_lote year) vce(cluster codigo_barrio);
    #d cr
    estimates store triple_`offset'
    estimates save "${dir_outcomes}\triple_`offset'.ster", replace
    local d = 1/(400+`offset') - 1/(800+`offset')
    display "offset `offset': premio en A=0 (%) = " ///
        100*(exp(`d'*_b[c.post#c.prox`offset'])-1)
    display "offset `offset': premio en A=1 (%) = " ///
        100*(exp(`d'*(_b[c.post#c.prox`offset'] + ///
        _b[c.post#c.prox`offset'#c.A_std]))-1)
}

*---------
* Dinámica por tercil de A (figura 4)
*---------

xtile A_tercil = A_std if !missing(ln_avaluo_real_2014, prox1000, A_std), nq(3)
tempfile dinamica
tempname ph
postfile `ph' byte tercil int year double b se using `dinamica', replace
foreach tercil in 1 3 {
    preserve
    keep if A_tercil == `tercil'
    local gvars
    foreach yy of numlist 2014/2017 2019/2025 {
        gen double g`yy' = (year == `yy')*prox1000
        local gvars `gvars' g`yy'
    }
    reghdfe ln_avaluo_real_2014 `gvars', ///
        absorb(codigo_lote year) vce(cluster codigo_barrio)
    estimates store dinamica_`tercil'
    estimates save "${dir_outcomes}\dinamica_`tercil'.ster", replace
    test g2014 g2015 g2016 g2017
    foreach yy of numlist 2014/2017 2019/2025 {
        post `ph' (`tercil') (`yy') (_b[g`yy']) (_se[g`yy'])
    }
    restore
}
postclose `ph'
preserve
use `dinamica', clear
gen double premio = 100*(exp(`delta'*b)-1)
gen double li = 100*(exp(`delta'*(b-1.96*se))-1)
gen double ls = 100*(exp(`delta'*(b+1.96*se))-1)
export delimited using "${dir_outcomes}\dinamica_terciles.csv", replace
twoway (rcap li ls year if tercil==1, lcolor(maroon)) ///
       (connected premio year if tercil==1, lcolor(maroon) mcolor(maroon)) ///
       (rcap li ls year if tercil==3, lcolor(navy)) ///
       (connected premio year if tercil==3, lcolor(navy) mcolor(navy)), ///
       xlabel(2014 2016 2018 2020 2022 2025) ///
       xline(2018.5, lpattern(dash) lcolor(gs8)) ///
       yline(0, lcolor(gs8)) xtitle("Año") ///
       ytitle("Premio de 400 m frente a 800 m (%)") ///
       legend(order(2 "Tercil inferior" 4 "Tercil superior") rows(1))
graph export "${dir_outcomes}\fig_dynamic_terciles.pdf", replace
restore
}

*---------
* Empleo, CBD y equipamientos (tablas 5 y 6)
* La primera versión reproduce el borrador. La segunda agrega post × M
* para absorber cambios posteriores comunes a toda la ciudad según M.
*---------

foreach m in economic_access economic_access_gr economic_access_exp ///
    ln_dist_cbd amenities_index A_std {
    reghdfe ln_avaluo_real_2014 c.treat##c.`m', ///
        absorb(codigo_lote year) vce(cluster codigo_barrio)
    local n_original = e(N)
    estimates store zona_`m'
    estimates save "${dir_outcomes}\zona_`m'.ster", replace
    reghdfe ln_avaluo_real_2014 c.treat##c.`m' c.post#c.`m', ///
        absorb(codigo_lote year) vce(cluster codigo_barrio)
    if e(N) != `n_original' {
        display as error "La muestra cambió al agregar post × `m'."
        exit 459
    }
    estimates store z_`m'_pm
    estimates save "${dir_outcomes}\zona_`m'_postM.ster", replace
    estimates table zona_`m' z_`m'_pm, b(%9.4f) se(%9.4f) stats(N)
}
foreach m in access_group cbd_group {
    reghdfe ln_avaluo_real_2014 c.treat##i.`m', ///
        absorb(codigo_lote year) vce(cluster codigo_barrio)
    local n_original = e(N)
    estimates store zona_`m'
    estimates save "${dir_outcomes}\zona_`m'.ster", replace
    reghdfe ln_avaluo_real_2014 c.treat##i.`m' c.post##i.`m', ///
        absorb(codigo_lote year) vce(cluster codigo_barrio)
    if e(N) != `n_original' {
        display as error "La muestra cambió al agregar post × `m'."
        exit 459
    }
    estimates store z_`m'_pm
    estimates save "${dir_outcomes}\zona_`m'_postM.ster", replace
    estimates table zona_`m' z_`m'_pm, b(%9.4f) se(%9.4f) stats(N)
}

if "`main_only'" == "1" {
    log close
    exit
}
}

*---------
* Buffers de 400, 800 y 1200 m (tablas 3 y 7)
*---------

use codigo_lote year codigo_barrio c_barrio c_manzana ln_avaluo_real_2014 ///
    descripcion_destino treatment_400 treatment_800 treatment_1200 ///
    using "${dir_proc}\predios_robust.dta", clear
assert strlen(c_barrio) == 6 & strlen(c_manzana) == 2
gen str9 mancodigo = c_barrio + "0" + c_manzana
drop c_barrio c_manzana
merge m:1 mancodigo using "${dir_proc}\manzanas_access.dta", ///
    keep(master match) nogen ///
    keepusing(economic_access access_group ln_dist_cbd cbd_group amenities_index I_AccB)
gen byte post = year >= 2019
gen byte privado = !inlist(descripcion_destino, "VIAS", "ESPACIO PÚBLICO", ///
    "LOTE DEL ESTADO", "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO")
gen byte muestra_comun = !missing(ln_avaluo_real_2014, economic_access, ///
    access_group, ln_dist_cbd, cbd_group, amenities_index, I_AccB)
foreach b in 400 800 1200 {
    gen byte treat_`b' = (treatment_`b' == 1 & year >= 2019)
    reghdfe ln_avaluo_real_2014 treat_`b' if privado, ///
        absorb(codigo_lote year) vce(cluster codigo_barrio)
    estimates store buffer_`b'
    estimates save "${dir_outcomes}\buffer_`b'.ster", replace
    foreach m in economic_access ln_dist_cbd amenities_index {
        reghdfe ln_avaluo_real_2014 c.treat_`b'##c.`m' if muestra_comun, ///
            absorb(codigo_lote year) vce(cluster codigo_barrio)
        local n_original = e(N)
        estimates store buffer_`b'_`m'
        estimates save "${dir_outcomes}\buffer_`b'_`m'.ster", replace
        reghdfe ln_avaluo_real_2014 c.treat_`b'##c.`m' c.post#c.`m' ///
            if muestra_comun, absorb(codigo_lote year) vce(cluster codigo_barrio)
        if e(N) != `n_original' {
            display as error "La muestra cambió en buffer `b' al agregar post × `m'."
            exit 459
        }
        estimates store b_`b'_`m'_pm
        estimates save "${dir_outcomes}\buffer_`b'_`m'_postM.ster", replace
        estimates table buffer_`b'_`m' b_`b'_`m'_pm, ///
            b(%9.4f) se(%9.4f) stats(N)
    }
}

log close
