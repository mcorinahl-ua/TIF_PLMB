*==================================================
* 18_pretrends_atributos.do
* Tendencias previas por destino y estrato del registro en 2018.
* 6 Oct 2026. Usa la caché de 16_heterogeneidad_atributos.do.
* Requiere reghdfe. FE de lote y categoría por año; cluster barrio.
*==================================================

clear all
set more off
args results_dir etapa
if "`results_dir'" == "" local results_dir "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Paper/stata_results/diagnosticos_2026-10-06"
if "`etapa'" == "" local etapa "destino"
assert inlist("`etapa'", "destino", "estrato")
capture log close
log using "`results_dir'/atributos_previos_`etapa'.log", text replace
use "`results_dir'/atributos_comun_agrupado.dta", clear
keep if year <= 2018
local atributo destino2018
local base = 2
if "`etapa'" == "estrato" {
    keep if destino2018 == 2 & inrange(estrato2018, 1, 6)
    local atributo estrato2018
    local base = 1
}
quietly levelsof `atributo', local(categorias)
tempfile pruebas coeficientes
tempname pp pc
#d;
postfile `pp' int buffer categoria str18 prueba byte estimable
    double F p df df_r long n barrios using `pruebas', replace;
postfile `pc' int buffer categoria year byte estimable
    double b se p li ls using `coeficientes', replace;
#d cr

foreach b in 400 800 1200 {
    local eventos
    foreach c of local categorias {
        foreach yy of numlist 2014/2017 {
            gen byte t`c'_`yy' = `atributo' == `c' & year == `yy' & treatment_`b' == 1
            local eventos `eventos' t`c'_`yy'
        }
    }
    local niveles ib`base'.`atributo'#c.treatment_`b'
    local comunes
    local efectos "codigo_lote `atributo'#year"
    if "`etapa'" == "estrato" {
        * Solo un lote tratado mezcla estratos válidos (2 y 3). Los términos
        * de nivel casi colineales desestabilizan la proyección conjunta.
        * Restar la media del lote y escalar no cambia la ecuación con FE.
        sort codigo_lote
        tempvar filas_lote
        by codigo_lote: egen double `filas_lote' = total(n_registros)
        local niveles
        foreach c of local categorias {
            if `c' != `base' {
                gen byte a`c' = `atributo' == `c'
                gen byte at`c' = a`c' * treatment_`b'
                foreach prefijo in a at {
                    tempvar suma numerador
                    gen double `numerador' = `prefijo'`c' * n_registros
                    by codigo_lote: egen double `suma' = total(`numerador')
                    gen double z`prefijo'`c' = `prefijo'`c' - `suma' / `filas_lote'
                    drop `prefijo'`c' `suma' `numerador'
                    quietly summarize z`prefijo'`c' [fw=n_registros]
                    if r(sd) > 0 & r(sd) < . {
                        replace z`prefijo'`c' = z`prefijo'`c' / r(sd)
                        local niveles `niveles' z`prefijo'`c'
                    }
                    else drop z`prefijo'`c'
                }
                foreach yy of numlist 2014/2017 {
                    gen byte a`c'_`yy' = `atributo' == `c' & year == `yy'
                    local comunes `comunes' a`c'_`yy'
                }
            }
        }
        drop `filas_lote'
        * Quitar la duplicación exacta entre los contrastes de nivel 2 y 3.
        _rmcoll `niveles' [fw=n_registros], noconstant forcedrop
        local niveles `r(varlist)'
        * Dummies explícitas de categoría por año: la misma ecuación que
        * absorber categoría-año, con mejor estabilidad en los lotes mixtos.
        local efectos "codigo_lote year"
    }
    * Cada categoría puede tener cambios comunes propios por año.
    * Los cuatro términos de tratamiento por categoría se refieren a 2018.
    #d;
    reghdfe ln_avaluo_real_2014 `eventos' `niveles' `comunes' [fw=n_registros],
        absorb(`efectos') vce(cluster codigo_barrio)
        poolsize(1) compact;
    #d cr
    * Un EE faltante en un término con soporte es un fallo de la corrida.
    assert e(rank) > 0 & e(rank) < .
    foreach v of local eventos {
        quietly count if `v' != 0
        if r(N) > 0 assert _se[`v'] > 0 & _se[`v'] < .
    }
    estimates save "`results_dir'/atributos_previos_`etapa'_`b'.ster", replace
    local n = e(N)
    local g = e(N_clust)
    foreach c of local categorias {
        local estimable = 1
        local terminos
        foreach yy of numlist 2014/2017 {
            local terminos `terminos' t`c'_`yy'
            if _se[t`c'_`yy'] == 0 local estimable = 0
        }
        if `estimable' {
            quietly test `terminos'
            post `pp' (`b') (`c') ("efecto_categoria") (1) (r(F)) (r(p)) (r(df)) (r(df_r)) (`n') (`g')
        }
        else post `pp' (`b') (`c') ("efecto_categoria") (0) (.) (.) (.) (.) (`n') (`g')
        foreach yy of numlist 2014/2017 {
            if _se[t`c'_`yy'] > 0 {
                quietly lincom t`c'_`yy'
                post `pc' (`b') (`c') (`yy') (1) (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
            }
            else post `pc' (`b') (`c') (`yy') (0) (.) (.) (.) (.) (.)
        }
        if `c' != `base' {
            local estimable_base = 1
            local diferencias
            foreach yy of numlist 2014/2017 {
                if _se[t`base'_`yy'] == 0 local estimable_base = 0
                local diferencias `diferencias' (t`c'_`yy' = t`base'_`yy')
            }
            if `estimable' & `estimable_base' {
                quietly test `diferencias'
                post `pp' (`b') (`c') ("diferencia_base") (1) (r(F)) (r(p)) (r(df)) (r(df_r)) (`n') (`g')
            }
            else post `pp' (`b') (`c') ("diferencia_base") (0) (.) (.) (.) (.) (`n') (`g')
        }
    }
    drop `eventos'
    if "`etapa'" == "estrato" {
        drop za* a*_20*
    }
}
postclose `pp'
postclose `pc'
use `pruebas', clear
export delimited using "`results_dir'/atributos_previos_`etapa'_test.csv", replace
use `coeficientes', clear
export delimited using "`results_dir'/atributos_previos_`etapa'_coef.csv", replace
log close
