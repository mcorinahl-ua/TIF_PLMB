*==================================================
* 06_atributos.do
* Heterogeneidad por destino económico y por estrato residencial, con el
* atributo de cada registro en 2018, y sus tendencias previas.
* Oct 2026. Correr desde 00_master.do. Requiere reghdfe.
*
* Referencias: residencial para destino y estrato 2 para estrato (el
* estrato 1 tiene muy pocos barrios tratados y el 6 aún menos).
*==================================================

clear all
set more off
cap log close
log using "${dir_res}06_atributos.log", text replace

*---------
* Efectos posteriores por categoría
*---------

tempname pr ps pt
tempfile resultados soporte pruebas
#d ;
postfile `pr' str7 atributo int buffer byte categoria str15 termino byte estimable
    double b se p li ls long n barrios using `resultados', replace;
postfile `ps' str7 atributo int buffer byte categoria long registros_tratados
    barrios_tratados using `soporte', replace;
postfile `pt' str7 atributo int buffer double F p df df_r using `pruebas', replace;
#d cr

foreach tipo in destino estrato {
    use "${dir_res}atributos_lote_anio.dta", clear
    local atributo destino2018
    local base = 2
    if "`tipo'" == "estrato" {
        keep if destino2018 == 2 & inrange(estrato2018, 1, 6)
        local atributo estrato2018
    }
    quietly levelsof `atributo', local(categorias)

    foreach b in 400 800 1200 {
        gen byte treat = post & treatment_`b' == 1

        ** Soporte tratado antes de 2019
        egen byte tag = tag(`atributo' codigo_barrio) if treatment_`b' == 1 & !post
        foreach c of local categorias {
            quietly summarize n_registros if `atributo' == `c' & treatment_`b' == 1 & !post
            local registros = r(sum)
            quietly count if tag == 1 & `atributo' == `c'
            post `ps' ("`tipo'") (`b') (`c') (`registros') (r(N))
        }
        drop tag

        ** El atributo varía entre registros del mismo lote, así que el FE de
        ** lote no absorbe los términos de nivel por categoría
        #d ;
        reghdfe ln_avaluo_real_2014 ib`base'.`atributo'##c.treat
            ib`base'.`atributo'#c.post ib`base'.`atributo'#c.treatment_`b'
            [fw=n_registros], absorb(codigo_lote year) vce(cluster codigo_barrio)
            poolsize(1) compact;
        #d cr
        estimates save "${dir_res}atributos_`tipo'_`b'.ster", replace
        local n = e(N)
        local g = e(N_clust)

        local diferencias
        foreach c of local categorias {
            local estimable = _se[treat] > 0
            local contraste "treat"
            if `c' != `base' {
                local contraste "treat + `c'.`atributo'#c.treat"
                capture scalar se_c = _se[`c'.`atributo'#c.treat]
                if _rc local estimable = 0
                else if se_c == 0 local estimable = 0
            }
            if `estimable' {
                quietly lincom `contraste'
                post `pr' ("`tipo'") (`b') (`c') ("efecto_total") (1) ///
                    (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n') (`g')
                if `c' != `base' {
                    quietly lincom `c'.`atributo'#c.treat
                    post `pr' ("`tipo'") (`b') (`c') ("diferencia_base") (1) ///
                        (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n') (`g')
                    local diferencias `diferencias' `c'.`atributo'#c.treat
                }
            }
            else post `pr' ("`tipo'") (`b') (`c') ("efecto_total") (0) (.) (.) (.) (.) (.) (`n') (`g')
        }

        ** Prueba conjunta de las diferencias frente a la referencia
        quietly test `diferencias'
        post `pt' ("`tipo'") (`b') (r(F)) (r(p)) (r(df)) (r(df_r))
        drop treat
    }
}
postclose `pr'
postclose `ps'
postclose `pt'

use `resultados', clear
gen double cambio_pct = 100 * (exp(b) - 1)
gen double cambio_li = 100 * (exp(li) - 1)
gen double cambio_ls = 100 * (exp(ls) - 1)
export delimited using "${dir_res}atributos_coef.csv", replace
use `soporte', clear
export delimited using "${dir_res}atributos_soporte.csv", replace
use `pruebas', clear
export delimited using "${dir_res}atributos_pruebas.csv", replace

*---------
* Tendencias previas por categoría
*---------

** Cada categoría tiene sus propios cambios por año. Los cuatro términos
** de tratamiento por categoría se miden frente a 2018.
tempname pp
tempfile previos
#d ;
postfile `pp' str7 atributo int buffer byte categoria str15 prueba byte estimable
    double F p df df_r long n barrios using `previos', replace;
#d cr

foreach tipo in destino estrato {
    use "${dir_res}atributos_lote_anio.dta", clear
    keep if year <= 2018
    local atributo destino2018
    local base = 2
    if "`tipo'" == "estrato" {
        keep if destino2018 == 2 & inrange(estrato2018, 1, 6)
        local atributo estrato2018
    }
    quietly levelsof `atributo', local(categorias)

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

        if "`tipo'" == "estrato" {
            ** Casi ningún lote tratado mezcla estratos y los términos de nivel
            ** quedan casi colineales. Se les resta la media del lote (no
            ** cambia la ecuación con FE de lote) y la categoría por año va
            ** con dummies explícitas. Arreglo del 6 Oct 2026.
            sort codigo_lote
            by codigo_lote: egen double filas_lote = total(n_registros)
            local niveles
            foreach c of local categorias {
                if `c' != `base' {
                    gen byte a`c' = `atributo' == `c'
                    gen byte at`c' = a`c' * treatment_`b'
                    foreach prefijo in a at {
                        gen double num = `prefijo'`c' * n_registros
                        by codigo_lote: egen double suma = total(num)
                        gen double z`prefijo'`c' = `prefijo'`c' - suma / filas_lote
                        drop `prefijo'`c' suma num
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
            drop filas_lote
            _rmcoll `niveles' [fw=n_registros], noconstant forcedrop
            local niveles `r(varlist)'
            local efectos "codigo_lote year"
        }

        #d ;
        reghdfe ln_avaluo_real_2014 `eventos' `niveles' `comunes' [fw=n_registros],
            absorb(`efectos') vce(cluster codigo_barrio)
            poolsize(1) compact;
        #d cr
        estimates save "${dir_res}atributos_previos_`tipo'_`b'.ster", replace
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
                post `pp' ("`tipo'") (`b') (`c') ("efecto_categoria") (1) ///
                    (r(F)) (r(p)) (r(df)) (r(df_r)) (`n') (`g')
            }
            else post `pp' ("`tipo'") (`b') (`c') ("efecto_categoria") (0) (.) (.) (.) (.) (`n') (`g')

            if `c' != `base' {
                local estimable_base = 1
                local diferencias
                foreach yy of numlist 2014/2017 {
                    if _se[t`base'_`yy'] == 0 local estimable_base = 0
                    local diferencias `diferencias' (t`c'_`yy' = t`base'_`yy')
                }
                if `estimable' & `estimable_base' {
                    quietly test `diferencias'
                    post `pp' ("`tipo'") (`b') (`c') ("diferencia_base") (1) ///
                        (r(F)) (r(p)) (r(df)) (r(df_r)) (`n') (`g')
                }
                else post `pp' ("`tipo'") (`b') (`c') ("diferencia_base") (0) (.) (.) (.) (.) (`n') (`g')
            }
        }
        drop `eventos'
        if "`tipo'" == "estrato" drop za* a*_20*
    }
}
postclose `pp'

use `previos', clear
export delimited using "${dir_res}atributos_previos.csv", replace

log close
