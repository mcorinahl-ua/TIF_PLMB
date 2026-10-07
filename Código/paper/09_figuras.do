*==================================================
* 09_figuras.do
* Figuras del paper desde los CSV de resultados; no estima nada.
* Oct 2026. Correr desde 00_master.do.
* Figura 2: event study promedio. 3: contraste según A. 4: interacción
* anual. 5: sensibilidad de Rambachan y Roth. C1 y C2: terciles de A.
*==================================================

clear all
set more off
cap log close
log using "${dir_res}09_figuras.log", text replace

*---------
* Figura 2: event study promedio de 400 y 800 m
*---------

import delimited using "${dir_res}evento_coef.csv", clear asdouble
keep if inlist(buffer, 400, 800)
gen double estimacion = 100 * (exp(b) - 1)
gen double inferior = 100 * (exp(li) - 1)
gen double superior = 100 * (exp(ls) - 1)

** 2018 es el año omitido: cero por normalización
local primera = _N + 1
local segunda = _N + 2
set obs `segunda'
replace buffer = 400 in `primera'
replace buffer = 800 in `segunda'
replace year = 2018 if missing(year)
replace estimacion = 0 if year == 2018
gen double posicion = year + cond(buffer == 400, -.1, .1)

#d ;
twoway
    (rcap inferior superior posicion if buffer == 400, lcolor(navy))
    (scatter estimacion posicion if buffer == 400 & year != 2018,
        mcolor(navy) msymbol(O))
    (scatter estimacion posicion if buffer == 400 & year == 2018,
        mcolor(navy) msymbol(Oh))
    (rcap inferior superior posicion if buffer == 800, lcolor(dkorange))
    (scatter estimacion posicion if buffer == 800 & year != 2018,
        mcolor(dkorange) msymbol(O))
    (scatter estimacion posicion if buffer == 800 & year == 2018,
        mcolor(dkorange) msymbol(Oh)),
    xlabel(2014(1)2025, labsize(small)) xscale(range(2013.5 2025.5))
    ylabel(-4(2)10, angle(horizontal) grid)
    xline(2018.5, lcolor(gs10) lpattern(dash)) yline(0, lcolor(gs8))
    xtitle("Year") ytitle("Change in assessed value relative to 2018 (%)", size(small))
    legend(order(2 "Within 400 m" 5 "Within 800 m")
        position(11) ring(0) cols(1) region(lstyle(none)))
    graphregion(color(white)) plotregion(color(white))
    xsize(7.2) ysize(4.2) name(event_study_promedio, replace);
#d cr
graph export "${dir_res}figura2_event_study.png", replace width(2160)

*---------
* Figura 3: contraste de proximidad según A
*---------

import delimited using "${dir_res}gradiente_curva.csv", clear asdouble
#d ;
twoway (rarea cambio_li cambio_ls a, fcolor(gs13) fintensity(100) lcolor(gs13))
    (line cambio_li cambio_ls a, lcolor(gs9 gs9) lwidth(vthin vthin))
    (line cambio_pct a, lcolor(navy) lwidth(medthick)),
    yline(0, lcolor(gs8) lpattern(dash))
    xline(0, lcolor(gs10) lpattern(shortdash))
    xtitle("Structural accessibility A (standard deviations)")
    ytitle("Post-period change in the proximity contrast (%)")
    xlabel(, labsize(medium)) ylabel(, angle(horizontal) labsize(medium))
    note("400 m versus 800 m. Post period: 2019-2025. 95% confidence interval."
         "Curve shown between the 1st and 99th percentiles of the common record sample.", size(small))
    legend(off) graphregion(color(white)) plotregion(color(white));
#d cr
graph export "${dir_res}figura3_gradiente.png", width(1800) replace

*---------
* Figura 4: interacción anual proximidad x A
*---------

import delimited using "${dir_res}gradiente_anual_coef.csv", clear asdouble
keep if modelo == "anual" & familia == "qa"
ren (logpuntos logpuntos_li logpuntos_ls) (estimacion inferior superior)
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
graph export "${dir_res}figura4_interaccion_anual.png", replace width(1800)

*---------
* Figura 5: sensibilidad del promedio anual de la interacción
*---------

import delimited using "${dir_res}honestdid_gradiente.csv", clear case(lower) asdouble
keep if objetivo == "anual_qa_ref2018" & delta == "rm"
gen byte convencional = missing(m)
gsort -convencional m
gen byte posicion = _n
list m inferior superior

#d ;
twoway
    (rcap inferior superior posicion if inferior > 0,
        horizontal lcolor(navy) lwidth(medthick))
    (rcap inferior superior posicion if inferior <= 0,
        horizontal lcolor(gs8) lwidth(medthick)),
    ylabel(1 "Conventional" 2 "M = 0" 3 "M = 0.25" 4 "M = 0.5"
        5 "M = 0.75" 6 "M = 1" 7 "M = 1.5" 8 "M = 2",
        angle(horizontal) noticks)
    yscale(reverse range(.5 8.5))
    xlabel(-2(2)6, grid) xline(0, lcolor(gs10) lpattern(dash))
    xtitle("Average 2019-2025 interaction relative to 2018 (log points x 100)", size(small))
    ytitle("Bound on annual counterfactual changes", size(small))
    legend(off) graphregion(color(white)) plotregion(color(white))
    xsize(7.2) ysize(4.4) name(sensibilidad_temporal, replace);
#d cr
graph export "${dir_res}figura5_sensibilidad.png", replace width(2160)

*---------
* Figuras C1 y C2: gradientes de los terciles extremos de A
*---------

import delimited using "${dir_res}terciles_coef.csv", clear
local filas = _N
set obs `=`filas' + 3'
replace year = 2018 in `=`filas' + 1'/L
replace termino = "inferior" in `=`filas' + 1'
replace termino = "superior" in `=`filas' + 2'
replace termino = "diferencia" in `=`filas' + 3'
foreach v in premio premio_li premio_ls contraste_log contraste_li contraste_ls {
    replace `v' = 0 if year == 2018
}
sort termino year
#d ;
twoway
    (rcap premio_li premio_ls year if termino == "inferior", lcolor(maroon))
    (connected premio year if termino == "inferior", lcolor(maroon) mcolor(maroon))
    (rcap premio_li premio_ls year if termino == "superior", lcolor(navy))
    (connected premio year if termino == "superior", lcolor(navy) mcolor(navy)),
    xlabel(2014(1)2025, angle(45)) xline(2018.5, lpattern(dash))
    yline(0, lcolor(gs8)) xtitle("Year")
    ytitle("Change in proximity contrast (%)")
    note("400 m versus 800 m. Reference year: 2018.")
    legend(order(2 "Lower tercile" 4 "Upper tercile") rows(1) position(6))
    graphregion(color(white));
#d cr
graph export "${dir_res}figuraC1_terciles.png", width(1800) replace
#d ;
twoway
    (rcap contraste_li contraste_ls year if termino == "diferencia", lcolor(navy))
    (connected contraste_log year if termino == "diferencia", lcolor(navy) mcolor(navy)),
    xlabel(2014(1)2025, angle(45)) xline(2018.5, lpattern(dash))
    yline(0, lcolor(gs8)) xtitle("Year")
    ytitle("Difference in changes (log points x 100)")
    note("400 m versus 800 m. Upper minus lower, relative to 2018.")
    legend(off) graphregion(color(white));
#d cr
graph export "${dir_res}figuraC2_terciles_diferencia.png", width(1800) replace

log close
