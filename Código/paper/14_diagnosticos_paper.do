*==================================================
* 14_diagnosticos_paper.do
* Muestra común, moderación y tendencias previas del paper.
* 6 Oct 2026. Buffers de 400/800/1200 m y distancia continua.
* Requiere reghdfe. Post desde 2019; referencia dinámica: 2018.
* La agrupación conserva b y VCE por barrio; R2 y RMSE corresponden
* a las medias agrupadas y no deben usarse como ajuste del panel original.
*==================================================

clear all
set more off
args results_dir etapa idioma
if "`idioma'" == "" local idioma "es"
assert inlist("`idioma'", "es", "en")
if "${dir_proc}" == "" global dir_proc "C:\Users\USUARIO\OneDrive - Universidad de los andes\RA Andes - TIF\Datos\processed"
if "`results_dir'" == "" local results_dir "C:\Users\USUARIO\OneDrive - Universidad de los andes\RA Andes - TIF\Paper\stata_results\diagnosticos_2026-10-06"
if "`etapa'" == "" local etapa "preparar"
assert inlist("`etapa'", "preparar", "armonizar", "verificar", "moderacion", "pretrends", "terciles", "buffers", "gradiente", "figuras")
capture mkdir "`results_dir'"
capture log close
log using "`results_dir'/`etapa'.log", text replace

*---------
* Preparar las muestras sin cambiar el peso de los registros
*---------

if "`etapa'" == "preparar" {
    * Preparar otra vez invalida la verificación anterior.
    capture erase "`results_dir'\agrupacion_verificada.txt"
    use codigo_lote year codigo_barrio c_barrio c_manzana ///
        ln_avaluo_real_2014 descripcion_destino ///
        treatment_400 treatment_800 treatment_1200 ///
        using "${dir_proc}\predios_robust.dta", clear
    assert inrange(year, 2014, 2025)
    keep if !inlist(descripcion_destino, "VIAS", "ESPACIO PÚBLICO", ///
        "LOTE DEL ESTADO", "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO")
    keep if !missing(ln_avaluo_real_2014)
    local n_privados = _N
    assert strlen(c_barrio) == 6 & strlen(c_manzana) == 2
    gen str9 mancodigo = c_barrio + "0" + c_manzana
    drop c_barrio c_manzana descripcion_destino
    foreach b in 400 800 1200 {
        assert inlist(treatment_`b', 0, 1)
    }
    assert treatment_400 <= treatment_800
    assert treatment_800 <= treatment_1200
    sort codigo_lote year
    foreach v in codigo_barrio mancodigo treatment_400 treatment_800 treatment_1200 {
        by codigo_lote: assert `v' == `v'[1]
    }

    * Dentro de lote-año los regresores son iguales. La media del log y
    * el número de filas conservan los coeficientes y la VCE por barrio.
    * No usar el log del avalúo promedio ni dar el mismo peso a cada lote.
    recast double ln_avaluo_real_2014
    #d;
    collapse (mean) ln_avaluo_real_2014
        (count) n_registros=ln_avaluo_real_2014,
        by(codigo_lote year codigo_barrio mancodigo
           treatment_400 treatment_800 treatment_1200);
    #d cr
    recast long n_registros
    isid codigo_lote year
    quietly summarize n_registros, meanonly
    assert r(sum) == `n_privados'
    save "`results_dir'\privados_lote_anio.dta", replace
}

if inlist("`etapa'", "preparar", "armonizar") {
    if "`etapa'" == "armonizar" use "`results_dir'\privados_lote_anio.dta", clear

    merge m:1 mancodigo using "${dir_proc}\manzanas_access.dta", ///
        keep(master match) keepusing(dist_plmb A_std A_rank ///
        economic_access ln_dist_cbd amenities_index)
    gen byte muestra_comun = !missing(dist_plmb, A_std, A_rank, ///
        economic_access, ln_dist_cbd, amenities_index) & dist_plmb >= 0

    preserve
    gen double registros_sin_A = n_registros * missing(A_std)
    gen double registros_sin_empleo = n_registros * missing(economic_access)
    gen double registros_sin_cbd = n_registros * missing(ln_dist_cbd)
    gen double registros_sin_equip = n_registros * missing(amenities_index)
    gen double registros_sin_dist = n_registros * (missing(dist_plmb) | dist_plmb < 0)
    gen double registros_comunes = n_registros * muestra_comun
    #d;
    collapse (sum) n_registros registros_comunes registros_sin_A
        registros_sin_empleo registros_sin_cbd registros_sin_equip
        registros_sin_dist, by(year);
    #d cr
    export delimited using "`results_dir'\cobertura_muestra.csv", replace
    restore

    keep if muestra_comun
    drop muestra_comun _merge
    gen byte post = year >= 2019
    gen double prox1000 = 1 / (dist_plmb + 1000)
    * Terciles ponderados por registros, como en la figura anterior.
    xtile A_tercil = A_std [fw=n_registros], nq(3)
    save "`results_dir'\comun_lote_anio.dta", replace
    preserve
    bysort codigo_lote (year): keep if _n == 1
    gen byte un_lote = 1
    collapse (sum) lotes=un_lote, ///
        by(treatment_400 treatment_800 treatment_1200 A_tercil)
    export delimited using "`results_dir'\lotes_por_buffer_tercil.csv", replace
    restore
}

*---------
* Verificar la agrupación contra una estimación anterior
*---------

if "`etapa'" == "verificar" {
    estimates use "`results_dir'\..\pretrends_buffer_400.ster"
    matrix b_anterior = e(b)
    matrix V_anterior = e(V)
    local n_anterior = e(N)
    local g_anterior = e(N_clust)
    local df_anterior = e(df_r)
    use "`results_dir'\privados_lote_anio.dta", clear
    local eventos
    foreach yy of numlist 2014/2017 2019/2025 {
        gen byte e400_`yy' = year == `yy' & treatment_400 == 1
        local eventos `eventos' e400_`yy'
    }
    reghdfe ln_avaluo_real_2014 `eventos' [fw=n_registros], ///
        absorb(codigo_lote year) vce(cluster codigo_barrio) poolsize(1) compact
    assert e(N) == `n_anterior'
    assert e(N_clust) == `g_anterior'
    assert e(df_r) == `df_anterior'
    matrix b_agrupado = e(b)
    matrix V_agrupado = e(V)
    mata: st_numscalar("dif_b", max(abs(st_matrix("b_agrupado") - st_matrix("b_anterior"))))
    mata: st_numscalar("dif_v", max(abs(st_matrix("V_agrupado") - st_matrix("V_anterior"))))
    display "Diferencia máxima en coeficientes: " dif_b
    display "Diferencia máxima en VCE: " dif_v
    assert dif_b < 1e-7
    assert dif_v < 1e-9
    test e400_2014 e400_2015 e400_2016 e400_2017
    file open ok using "`results_dir'\agrupacion_verificada.txt", write replace
    file write ok "Coeficientes, VCE, N, barrios y grados de libertad verificados." _n
    file close ok
}

* Las etapas siguientes requieren que la verificación haya pasado.
if inlist("`etapa'", "moderacion", "pretrends", "terciles", "buffers", "gradiente") {
    confirm file "`results_dir'\agrupacion_verificada.txt"
    use "`results_dir'\comun_lote_anio.dta", clear
}

*---------
* Dinámica del ATT sobre la muestra común de moderadores
*---------

if "`etapa'" == "buffers" {
    tempfile pruebas coeficientes
    tempname pp pc
    postfile `pp' int buffer double F p long n barrios using `pruebas', replace
    postfile `pc' int buffer year double b se p li ls using `coeficientes', replace
    foreach b in 400 800 1200 {
        local eventos
        foreach yy of numlist 2014/2017 2019/2025 {
            gen byte t`yy' = year == `yy' & treatment_`b' == 1
            local eventos `eventos' t`yy'
        }
        reghdfe ln_avaluo_real_2014 `eventos' [fw=n_registros], ///
            absorb(codigo_lote year) vce(cluster codigo_barrio) poolsize(1) compact
        local n = e(N)
        local g = e(N_clust)
        estimates save "`results_dir'\dinamico_comun_`b'.ster", replace
        test t2014 t2015 t2016 t2017
        post `pp' (`b') (r(F)) (r(p)) (`n') (`g')
        foreach yy of numlist 2014/2017 2019/2025 {
            quietly lincom t`yy'
            post `pc' (`b') (`yy') (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
        }
        drop `eventos'
    }
    postclose `pp'
    postclose `pc'
    use `pruebas', clear
    export delimited using "`results_dir'\pretrends_att_comun_test.csv", replace
    use `coeficientes', clear
    export delimited using "`results_dir'\pretrends_att_comun_coef.csv", replace
}

*---------
* Gradiente continuo con el índice nuevo sobre la misma muestra
*---------

if "`etapa'" == "gradiente" {
    #d;
    reghdfe ln_avaluo_real_2014 c.post#c.prox1000 c.post#c.A_std
        c.post#c.prox1000#c.A_std [fw=n_registros],
        absorb(codigo_lote year) vce(cluster codigo_barrio)
        poolsize(1) compact;
    #d cr
    estimates save "`results_dir'\gradiente_comun_A_std.ster", replace
    local n = e(N)
    local g = e(N_clust)
    tempfile resultados
    tempname pr
    postfile `pr' str25 termino double b se p li ls long n barrios using `resultados', replace
    foreach termino in c.post#c.prox1000 c.post#c.A_std c.post#c.prox1000#c.A_std {
        quietly lincom `termino'
        post `pr' ("`termino'") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n') (`g')
    }
    postclose `pr'
    use `resultados', clear
    export delimited using "`results_dir'\gradiente_comun.csv", replace
}

*---------
* Moderaciones con y sin post por moderador sobre idéntica muestra
*---------

if "`etapa'" == "moderacion" {
    tempfile resultados
    tempname pr
    postfile `pr' int buffer str25 moderador str12 version str20 termino ///
        double b se p li ls long n barrios using `resultados', replace
    foreach b in 400 800 1200 {
        gen byte treat = post & treatment_`b' == 1
        reghdfe ln_avaluo_real_2014 treat [fw=n_registros], ///
            absorb(codigo_lote year) vce(cluster codigo_barrio) poolsize(1) compact
        local n_comun = e(N)
        estimates save "`results_dir'\comun_`b'_att.ster", replace
        local g = e(N_clust)
        quietly lincom treat
        post `pr' (`b') ("sin_moderador") ("original") ("tratamiento") ///
            (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n_comun') (`g')
        foreach m in A_std economic_access ln_dist_cbd amenities_index {
            forvalues v = 0/1 {
                local adicional
                local version "original"
                if `v' == 1 {
                    local adicional "c.post#c.`m'"
                    local version "postM"
                }
                #d;
                reghdfe ln_avaluo_real_2014 treat c.treat#c.`m'
                    `adicional' [fw=n_registros],
                    absorb(codigo_lote year) vce(cluster codigo_barrio)
                    poolsize(1) compact;
                #d cr
                assert e(N) == `n_comun'
                local g = e(N_clust)
                estimates save "`results_dir'\comun_`b'_`m'_`version'.ster", replace
                quietly lincom c.treat#c.`m'
                post `pr' (`b') ("`m'") ("`version'") ("tratamiento_x_M") ///
                    (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n_comun') (`g')
                if `v' == 1 {
                    quietly lincom c.post#c.`m'
                    post `pr' (`b') ("`m'") ("`version'") ("post_x_M") ///
                        (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n_comun') (`g')
                }
            }
        }
        drop treat
    }
    postclose `pr'
    use `resultados', clear
    export delimited using "`results_dir'\moderacion_comun.csv", replace
}

*---------
* Tendencias anteriores a 2019 condicionadas por cada moderador
*---------

if "`etapa'" == "pretrends" {
    keep if year <= 2018
    * Centrar M en la media pretratamiento de esta muestra. La prueba de
    * nivel corresponde así a una manzana con M promedio, no a M=0 bruto.
    foreach m in A_std economic_access ln_dist_cbd amenities_index {
        quietly summarize `m' [fw=n_registros], meanonly
        replace `m' = `m' - r(mean)
    }
    tempfile pruebas coeficientes
    tempname pp pc
    postfile `pp' int buffer str25 moderador str20 prueba double F p ///
        long n barrios using `pruebas', replace
    postfile `pc' int buffer str25 moderador int year str15 termino ///
        double b se p li ls long n using `coeficientes', replace
    foreach b in 400 800 1200 {
        foreach m in A_std economic_access ln_dist_cbd amenities_index {
            local eventos
            local interacciones
            foreach yy of numlist 2014/2017 {
                gen byte t`yy' = year == `yy' & treatment_`b' == 1
                gen double m`yy' = (year == `yy') * `m'
                gen double tm`yy' = t`yy' * `m'
                local eventos `eventos' t`yy' m`yy' tm`yy'
                local interacciones `interacciones' tm`yy'
            }
            #d;
            reghdfe ln_avaluo_real_2014 `eventos' [fw=n_registros],
                absorb(codigo_lote year) vce(cluster codigo_barrio)
                poolsize(1) compact;
            #d cr
            local n = e(N)
            local g = e(N_clust)
            estimates save "`results_dir'\previos_`b'_`m'.ster", replace
            test t2014 t2015 t2016 t2017
            post `pp' (`b') ("`m'") ("nivel") (r(F)) (r(p)) (`n') (`g')
            test `interacciones'
            post `pp' (`b') ("`m'") ("heterogeneidad") (r(F)) (r(p)) (`n') (`g')
            test t2014 t2015 t2016 t2017 `interacciones'
            post `pp' (`b') ("`m'") ("conjunta") (r(F)) (r(p)) (`n') (`g')
            foreach yy of numlist 2014/2017 {
                foreach prefijo in t tm {
                    quietly lincom `prefijo'`yy'
                    post `pc' (`b') ("`m'") (`yy') ("`prefijo'") ///
                        (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n')
                }
            }
            drop `eventos'
        }
    }
    postclose `pp'
    postclose `pc'
    use `pruebas', clear
    export delimited using "`results_dir'\pretrends_moderadores_test.csv", replace
    use `coeficientes', clear
    export delimited using "`results_dir'\pretrends_moderadores_coef.csv", replace
}

*---------
* Comparar directamente los gradientes de los terciles extremos
*---------

if "`etapa'" == "terciles" {
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
    * Año por tercil permite cambios comunes propios de cada grupo.
    #d;
    reghdfe ln_avaluo_real_2014 `eventos' [fw=n_registros],
        absorb(codigo_lote alto#year) vce(cluster codigo_barrio)
        poolsize(1) compact;
    #d cr
    estimates save "`results_dir'\terciles_conjunto.ster", replace
    local n = e(N)
    local g = e(N_clust)
    tempfile pruebas dinamica
    tempname pp pc
    postfile `pp' str20 prueba double F p long n barrios using `pruebas', replace
    test g2014 g2015 g2016 g2017
    post `pp' ("tercil_inferior") (r(F)) (r(p)) (`n') (`g')
    test (g2014 + dg2014 = 0) (g2015 + dg2015 = 0) ///
        (g2016 + dg2016 = 0) (g2017 + dg2017 = 0)
    post `pp' ("tercil_superior") (r(F)) (r(p)) (`n') (`g')
    test `diferencias_previas'
    post `pp' ("diferencia_terciles") (r(F)) (r(p)) (`n') (`g')
    postfile `pc' int year str15 termino double b se p li ls using `dinamica', replace
    foreach yy of numlist 2014/2017 2019/2025 {
        quietly lincom g`yy'
        post `pc' (`yy') ("inferior") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
        quietly lincom g`yy' + dg`yy'
        post `pc' (`yy') ("superior") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
        quietly lincom dg`yy'
        post `pc' (`yy') ("diferencia") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
    }
    postclose `pp'
    postclose `pc'
    use `pruebas', clear
    export delimited using "`results_dir'\terciles_test.csv", replace
    use `dinamica', clear
    local delta = 1/1400 - 1/1800
    gen double premio = 100 * (exp(`delta' * b) - 1)
    gen double premio_li = 100 * (exp(`delta' * li) - 1)
    gen double premio_ls = 100 * (exp(`delta' * ls) - 1)
    export delimited using "`results_dir'\terciles_coef.csv", replace
}

if inlist("`etapa'", "terciles", "figuras") {
    if "`etapa'" == "figuras" import delimited "`results_dir'\terciles_coef.csv", clear
    local delta = 1/1400 - 1/1800
    * La diferencia se muestra en log puntos, no como diferencia de porcentajes.
    capture drop contraste_log contraste_li contraste_ls
    gen double contraste_log = 100 * `delta' * b
    gen double contraste_li = 100 * `delta' * li
    gen double contraste_ls = 100 * `delta' * ls
    if "`etapa'" == "terciles" export delimited using "`results_dir'\terciles_coef.csv", replace
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
    local eje_x "Año"
    local eje_y "Cambio del premio frente a 2018 (%)"
    local eje_dif "Diferencia de cambios (log puntos x 100)"
    local inferior "Tercil inferior"
    local superior "Tercil superior"
    local nota "Contraste de 400 frente a 800 m. 2018: referencia."
    local nota_dif "400 frente a 800 m. Superior menos inferior, respecto a 2018."
    local sufijo
    if "`idioma'" == "en" {
        local eje_x "Year"
        local eje_y "Change in proximity contrast (%)"
        local eje_dif "Difference in changes (log points x 100)"
        local inferior "Lower tercile"
        local superior "Upper tercile"
        local nota "400 m versus 800 m. Reference year: 2018."
        local nota_dif "400 m versus 800 m. Upper minus lower, relative to 2018."
        local sufijo "_en"
    }
    #d;
    twoway
        (rcap premio_li premio_ls year if termino == "inferior", lcolor(maroon))
        (connected premio year if termino == "inferior", lcolor(maroon) mcolor(maroon))
        (rcap premio_li premio_ls year if termino == "superior", lcolor(navy))
        (connected premio year if termino == "superior", lcolor(navy) mcolor(navy)),
        xlabel(2014(1)2025, angle(45)) xline(2018.5, lpattern(dash))
        yline(0, lcolor(gs8)) xtitle("`eje_x'")
        ytitle("`eje_y'")
        note("`nota'")
        legend(order(2 "`inferior'" 4 "`superior'") rows(1) position(6))
        graphregion(color(white));
    #d cr
    graph export "`results_dir'\terciles_gradiente`sufijo'.png", width(1800) replace
    #d;
    twoway
        (rcap contraste_li contraste_ls year if termino == "diferencia", lcolor(navy))
        (connected contraste_log year if termino == "diferencia", lcolor(navy) mcolor(navy)),
        xlabel(2014(1)2025, angle(45)) xline(2018.5, lpattern(dash))
        yline(0, lcolor(gs8)) xtitle("`eje_x'")
        ytitle("`eje_dif'")
        note("`nota_dif'")
        legend(off) graphregion(color(white));
    #d cr
    graph export "`results_dir'\terciles_diferencia`sufijo'.png", width(1800) replace
}

log close
