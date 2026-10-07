*==================================================
* 25_sensibilidad_temporal.do
* Sensibilidad del gradiente anual a desviaciones de tendencias paralelas.
* 6 Oct 2026. Rambachan y Roth (2023), honestdid 1.3.0.
* Lee el modelo guardado; no vuelve a estimar.
* Objetivo: promedio anual 2019-2025 frente a 2018.
* Este contraste no es el coeficiente del modelo post agrupado.
*==================================================

clear all
set more off
args results_dir
if "`results_dir'" == "" local results_dir "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Paper/stata_results/diagnosticos_2026-10-06"
capture log close
log using "`results_dir'/sensibilidad_temporal.log", text replace
honestdid _plugin_check
estimates use "`results_dir'/gradiente_temporal_comun.ster"
assert e(N) == 25334749 & e(N_clust) == 952

*---------
* Extraer la interacción anual y toda su covarianza
*---------

local qa
foreach yy of numlist 2014/2017 2019/2025 {
    local qa `qa' qa`yy'
}
matrix bb = e(b)
matrix VV = e(V)
matrix beta = J(1,11,.)
matrix sigma = J(11,11,.)
local i = 0
foreach vi of local qa {
    local ++i
    local ci = colnumb(bb, "`vi'")
    assert `ci' > 0 & `ci' < .
    matrix beta[1,`i'] = bb[1,`ci']
    local j = 0
    foreach vj of local qa {
        local ++j
        local cj = colnumb(bb, "`vj'")
        matrix sigma[`i',`j'] = VV[`ci',`cj']
    }
}
matrix colnames beta = `qa'
matrix colnames sigma = `qa'
matrix rownames sigma = `qa'
local delta = 100*1000*(1/1400 - 1/1800)
matrix beta = `delta'*beta
matrix sigma = `delta'^2*sigma
matrix objetivo = J(7,1,1/7)

*---------
* M limita la variación anual del contrafactual posterior,
* relativa a la máxima variación anual previa, incluido 2018.
* M = 1 permite una variación tan grande como la previa.
* Las unidades son log puntos x 100, por una SD de A, 400 vs 800 m.
*---------

#d ;
honestdid, numpre(4) b(beta) vcov(sigma) l_vec(objetivo)
    delta(rm) mvec(0 .25 .5 .75 1 1.5 2)
    gridPoints(1000) mata(resultado_rm);
#d cr
mata st_matrix("intervalos", resultado_rm.CI)
mata st_matrix("abiertos", resultado_rm.open)
matrix list intervalos
matrix list abiertos
matrix colnames intervalos = M inferior superior
clear
svmat double intervalos, names(col)
svmat double abiertos, names(abierto)
assert !missing(inferior, superior)
assert inferior <= superior
gen str30 contraste = "post_2019_2025_vs_2018"
gen int periodos_previos = 4
gen int periodos_post = 7
export delimited using "`results_dir'/sensibilidad_temporal_rm.csv", replace
log close
