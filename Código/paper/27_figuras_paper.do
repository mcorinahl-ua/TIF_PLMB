*==================================================
* 27_figuras_paper.do
* Figuras 2 y 5 desde CSV guardados, sin volver a estimar modelos.
* 7 Oct 2026. Solo requiere comandos nativos de Stata.
*==================================================

clear all
set more off
args results_dir
if "`results_dir'" == "" local results_dir "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Paper/stata_results/diagnosticos_2026-10-06"
capture log close
log using "`results_dir'/figuras_paper.log", text replace

*---------
* Event study promedio: mismos coeficientes y transformación porcentual
*---------

import delimited using "`results_dir'/pretrends_att_comun_coef.csv", clear asdouble
isid buffer year
assert inlist(buffer, 400, 800, 1200)
keep if inlist(buffer, 400, 800)
assert _N == 22 & year != 2018
assert !missing(b, li, ls) & li <= b & b <= ls
gen double estimacion = 100*(exp(b)-1)
gen double inferior = 100*(exp(li)-1)
gen double superior = 100*(exp(ls)-1)

* 2018 es el año omitido: cero por normalización, sin intervalo estimado.
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
graph export "`results_dir'/event_study_promedio_en.png", replace width(2160)

*---------
* Sensibilidad del promedio anual de accesibilidad, no del post agrupado
*---------

import delimited using "`results_dir'/sensibilidad_temporal_rm.csv", clear case(lower) asdouble
assert _N == 8 & abierto1 == 0
assert !missing(inferior, superior) & inferior <= superior
assert periodos_previos == 4 & periodos_post == 7
assert contraste == "post_2019_2025_vs_2018"
gen byte convencional = missing(m)
gsort -convencional m
gen byte posicion = _n
assert missing(m) in 1
assert m == 0 in 2
assert m == .25 in 3
assert m == .5 in 4
assert m == .75 in 5
assert m == 1 in 6
assert m == 1.5 in 7
assert m == 2 in 8

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
graph export "`results_dir'/sensibilidad_temporal_en.png", replace width(2160)
log close
