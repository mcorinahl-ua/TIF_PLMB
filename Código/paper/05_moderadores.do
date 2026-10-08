*==================================================
* 05_moderadores.do
* DiD por buffer moderado por A, acceso al empleo, distancia al CBD y
* equipamientos, y tendencias previas por moderador.
* Oct 2026. 
* Requiere reghdfe.
*
* Versiones: original (treat x M), postM (agrega post x M, la principal),
* deciles (post por decil de M en vez de lineal) y conjunto (los cuatro
* moderadores a la vez). Los moderadores están correlacionados entre sí,
* así que el conjunto no separa canales independientes.
*==================================================

clear all
set more off
cap log close
log using "${dir_res}05_moderadores.log", text replace

use "${dir_res}comun_lote_anio.dta", clear
local moderadores A_std economic_access ln_dist_cbd amenities_index
foreach m of local moderadores {
    xtile dec_`m' = `m' [fw=n_registros], nq(10)
}

*---------
* Moderación del DiD
*---------

tempname pr
tempfile resultados
#d ;
postfile `pr' int buffer str16 moderador str8 version str16 termino
    double b se p li ls long n barrios using `resultados', replace;
#d cr

foreach b in 400 800 1200 {
    gen byte treat = post & treatment_`b' == 1
    foreach m of local moderadores {
        foreach version in original postM deciles {
            local adicional
            if "`version'" == "postM" local adicional c.post#c.`m'
            if "`version'" == "deciles" local adicional i(2/10).dec_`m'#c.post
            reghdfe ln_avaluo_real_2014 treat c.treat#c.`m' `adicional' [fw=n_registros], ///
                absorb(codigo_lote year) vce(cluster codigo_barrio) poolsize(1) compact
            estimates save "${dir_res}moderador_`b'_`m'_`version'.ster", replace
            quietly lincom c.treat#c.`m'
            #d ;
            post `pr' (`b') ("`m'") ("`version'") ("treat_x_M")
                (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N)) (e(N_clust));
            #d cr
            if "`version'" == "postM" {
                quietly lincom c.post#c.`m'
                #d ;
                post `pr' (`b') ("`m'") ("`version'") ("post_x_M")
                    (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N)) (e(N_clust));
                #d cr
            }
        }
    }

    ** Los cuatro moderadores juntos, cada uno con su post x M
    #d ;
    reghdfe ln_avaluo_real_2014 treat c.treat#c.(`moderadores') c.post#c.(`moderadores')
        [fw=n_registros], absorb(codigo_lote year) vce(cluster codigo_barrio)
        poolsize(1) compact;
    #d cr
    estimates save "${dir_res}moderador_`b'_conjunto.ster", replace
    foreach m of local moderadores {
        quietly lincom c.treat#c.`m'
        #d ;
        post `pr' (`b') ("`m'") ("conjunto") ("treat_x_M")
            (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N)) (e(N_clust));
        #d cr
    }
    drop treat
}
postclose `pr'
preserve
use `resultados', clear
export delimited using "${dir_res}moderacion.csv", replace
restore

*---------
* Tendencias previas por moderador
*---------

** 2014-2018 con 2018 omitido: año x tratamiento, año x M y año x
** tratamiento x M. M se centra en su media previa, así la prueba de
** nivel es para una manzana con M promedio.
keep if year <= 2018
foreach m of local moderadores {
    quietly summarize `m' [fw=n_registros], meanonly
    replace `m' = `m' - r(mean)
}

tempname pp pc
tempfile pruebas coeficientes
postfile `pp' int buffer str16 moderador str16 prueba double F p long n barrios using `pruebas', replace
postfile `pc' int buffer str16 moderador str8 termino int year double b se p li ls using `coeficientes', replace

foreach b in 400 800 1200 {
    foreach m of local moderadores {
        local eventos
        local interacciones
        foreach yy of numlist 2014/2017 {
            gen byte t`yy' = year == `yy' & treatment_`b' == 1
            gen double m`yy' = (year == `yy') * `m'
            gen double tm`yy' = t`yy' * `m'
            local eventos `eventos' t`yy' m`yy' tm`yy'
            local interacciones `interacciones' tm`yy'
        }
        reghdfe ln_avaluo_real_2014 `eventos' [fw=n_registros], ///
            absorb(codigo_lote year) vce(cluster codigo_barrio) poolsize(1) compact
        estimates save "${dir_res}previos_`b'_`m'.ster", replace
        local n = e(N)
        local g = e(N_clust)

        test t2014 t2015 t2016 t2017
        post `pp' (`b') ("`m'") ("nivel") (r(F)) (r(p)) (`n') (`g')
        test `interacciones'
        post `pp' (`b') ("`m'") ("pendiente") (r(F)) (r(p)) (`n') (`g')
        test t2014 t2015 t2016 t2017 `interacciones'
        post `pp' (`b') ("`m'") ("conjunta") (r(F)) (r(p)) (`n') (`g')
        test (tm2014 = tm2015) (tm2015 = tm2016) (tm2016 = tm2017)
        post `pp' (`b') ("`m'") ("pendiente_igual") (r(F)) (r(p)) (`n') (`g')

        foreach yy of numlist 2014/2017 {
            foreach prefijo in t tm {
                quietly lincom `prefijo'`yy'
                post `pc' (`b') ("`m'") ("`prefijo'") (`yy') (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
            }
        }
        ** Promedio 2014-2017 de la pendiente frente a 2018
        quietly lincom (tm2014 + tm2015 + tm2016 + tm2017) / 4
        post `pc' (`b') ("`m'") ("tm_prom") (0) (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
        drop `eventos'
    }
}
postclose `pp'
postclose `pc'

use `pruebas', clear
export delimited using "${dir_res}moderadores_previos_pruebas.csv", replace
use `coeficientes', clear
export delimited using "${dir_res}moderadores_previos_coef.csv", replace

log close
