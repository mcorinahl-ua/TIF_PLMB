*==================================================
* 16_heterogeneidad_atributos.do
* Heterogeneidad con destino y estrato de cada registro en 2018.
* 6 Oct 2026. Decisión de Corina: conservar atributos del registro;
* efectos fijos de lote y año, errores agrupados por barrio.
* Requiere reghdfe. Post desde 2019. Incluye post por categoría.
* Las medias del log se ponderan por filas; R2 corresponde a la agrupación.
*==================================================

clear all
set more off
args results_dir etapa usar_guardados
if "${dir_proc}" == "" global dir_proc "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Datos/processed"
if "`results_dir'" == "" local results_dir "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Paper/stata_results/diagnosticos_2026-10-06"
if "`etapa'" == "" local etapa "preparar"
if "`usar_guardados'" == "" local usar_guardados = 0
assert inlist(`usar_guardados', 0, 1)
assert inlist("`etapa'", "preparar", "destino", "estrato", "contrastes")
capture mkdir "`results_dir'"
capture log close
log using "`results_dir'/atributos_`etapa'.log", text replace

*---------
* Fijar los atributos por lote, construcción y resto en 2018
*---------

if "`etapa'" == "preparar" {
    #d;
    use codigo_lote codigo_construccion codigo_resto year codigo_estrato
        descripcion_destino ln_avaluo_real_2014 treatment_800
        using "${dir_proc}/predios_robust.dta", clear;
    #d cr
    keep if year == 2018
    keep if !inlist(descripcion_destino, "VIAS", "ESPACIO PÚBLICO", ///
        "LOTE DEL ESTADO", "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO") & !missing(ln_avaluo_real_2014)
    isid codigo_lote codigo_construccion codigo_resto
    gen byte destino2018 = 7
    #d;
    replace destino2018 = 1 if inlist(descripcion_destino, "AGRICOLA", "AGRÍCOLA",
        "AGROPECUARIO", "PECUARIO", "FORESTAL", "PREDIO RURAL PARCEL. NO EDIFI.");
    #d cr
    replace destino2018 = 2 if descripcion_destino == "RESIDENCIAL"
    #d;
    replace destino2018 = 3 if inlist(descripcion_destino, "COMERCIO EN CORREDOR COM",
        "COMERCIO PUNTUAL", "COMERCIO EN CENTRO COMER", "PARQUEADEROS");
    #d cr
    replace destino2018 = 4 if inlist(descripcion_destino, "INDUSTRIAL", "AGROINDUSTRIAL")
    replace destino2018 = 5 if descripcion_destino == "URBANIZADO NO EDIFICADO"
    replace destino2018 = 6 if descripcion_destino == "DOTACIONAL PRIVADO"
    rename codigo_estrato estrato2018
    rename treatment_800 treatment_800_2018
    keep codigo_lote codigo_construccion codigo_resto destino2018 estrato2018 treatment_800_2018
    save "`results_dir'/atributos_por_registro_2018.dta", replace

    #d;
    use codigo_lote codigo_construccion codigo_resto year codigo_barrio
        c_barrio c_manzana descripcion_destino ln_avaluo_real_2014
        treatment_400 treatment_800 treatment_1200
        using "${dir_proc}/predios_robust.dta", clear;
    #d cr
    keep if !inlist(descripcion_destino, "VIAS", "ESPACIO PÚBLICO", ///
        "LOTE DEL ESTADO", "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO") & !missing(ln_avaluo_real_2014)
    drop descripcion_destino
    isid codigo_lote codigo_construccion codigo_resto year
    merge m:1 codigo_lote codigo_construccion codigo_resto ///
        using "`results_dir'/atributos_por_registro_2018.dta", keep(master match)
    gen byte ficha2018 = _merge == 3
    assert treatment_800 == treatment_800_2018 if ficha2018
    drop _merge treatment_800_2018
    assert strlen(c_barrio) == 6 & strlen(c_manzana) == 2
    gen str9 mancodigo = c_barrio + "0" + c_manzana
    drop c_barrio c_manzana
    #d;
    merge m:1 mancodigo using "${dir_proc}/manzanas_access.dta",
        keep(master match) keepusing(dist_plmb A_std A_rank
        economic_access ln_dist_cbd amenities_index);
    #d cr
    gen byte muestra_comun = !missing(dist_plmb, A_std, A_rank, ///
        economic_access, ln_dist_cbd, amenities_index) & dist_plmb >= 0
    drop _merge dist_plmb A_std A_rank economic_access ln_dist_cbd amenities_index

    preserve
    gen byte privados = 1
    gen byte comunes = muestra_comun
    gen byte comunes_ficha2018 = muestra_comun & ficha2018
    gen byte residenciales_estrato = comunes_ficha2018 & destino2018 == 2 & inrange(estrato2018, 1, 6)
    collapse (sum) privados comunes comunes_ficha2018 residenciales_estrato, by(year)
    export delimited using "`results_dir'/atributos_cobertura.csv", replace
    restore

    * No asignar a fichas nuevas los atributos de otra construcción del lote.
    keep if muestra_comun & ficha2018
    drop muestra_comun ficha2018 codigo_construccion codigo_resto
    recast double ln_avaluo_real_2014
    #d;
    collapse (mean) ln_avaluo_real_2014
        (count) n_registros=ln_avaluo_real_2014,
        by(codigo_lote year codigo_barrio mancodigo destino2018 estrato2018
           treatment_400 treatment_800 treatment_1200);
    #d cr
    recast long n_registros
    isid codigo_lote year destino2018 estrato2018, missok
    gen byte post = year >= 2019
    save "`results_dir'/atributos_comun_agrupado.dta", replace
}

*---------
* Efectos totales por categoría e intervalos con covarianza conjunta
*---------

if inlist("`etapa'", "destino", "estrato") {
    use "`results_dir'/atributos_comun_agrupado.dta", clear
    local atributo destino2018
    local base = 2
    if "`etapa'" == "estrato" {
        keep if destino2018 == 2 & inrange(estrato2018, 1, 6)
        local atributo estrato2018
        local base = 1
    }
    tempfile resultados soporte
    tempname pr ps
    #d;
    postfile `pr' int buffer categoria str18 termino byte estimable
        double b se p li ls long n barrios using `resultados', replace;
    postfile `ps' int buffer categoria byte periodo tratado
        double registros long lotes barrios using `soporte', replace;
    #d cr
    foreach b in 400 800 1200 {
        gen byte treat = post & treatment_`b' == 1
        * Los atributos varían entre registros del mismo lote. Por eso sus
        * efectos de nivel y categoría por tratamiento se incluyen; el FE de
        * lote no absorbe todos esos términos cuando el lote es mixto.
        local leer = 0
        if `usar_guardados' {
            capture confirm file "`results_dir'/atributos_`etapa'_`b'.ster"
            if !_rc local leer = 1
        }
        if `leer' {
            * Solo reutilizar si la caché y la ecuación no han cambiado.
            estimates use "`results_dir'/atributos_`etapa'_`b'.ster"
            confirm matrix e(b)
            tempvar filas_lote
            bysort codigo_lote: egen double `filas_lote' = total(n_registros)
            gen byte muestra = `filas_lote' > 1
            quietly summarize n_registros if muestra, meanonly
            assert r(sum) == e(N)
            drop `filas_lote'
        }
        else {
            #d;
            reghdfe ln_avaluo_real_2014 ib`base'.`atributo'##c.treat
                ib`base'.`atributo'#c.post ib`base'.`atributo'#c.treatment_`b'
                [fw=n_registros],
                absorb(codigo_lote year) vce(cluster codigo_barrio)
                poolsize(1) compact;
            #d cr
            estimates save "`results_dir'/atributos_`etapa'_`b'.ster", replace
            gen byte muestra = e(sample)
        }
        local n = e(N)
        local g = e(N_clust)
        quietly levelsof `atributo' if muestra, local(categorias)
        preserve
        keep if muestra
        bysort `atributo' post treatment_`b' codigo_lote: gen byte un_lote = _n == 1
        bysort `atributo' post treatment_`b' codigo_barrio: gen byte un_barrio = _n == 1
        #d;
        collapse (sum) registros=n_registros lotes=un_lote barrios=un_barrio,
            by(`atributo' post treatment_`b');
        #d cr
        foreach c of local categorias {
            local cuatro_celdas = 1
            forvalues periodo = 0/1 {
                forvalues tratado = 0/1 {
                    local registros = 0
                    local lotes = 0
                    local barrios = 0
                    quietly count if `atributo' == `c' & post == `periodo' & treatment_`b' == `tratado'
                    if r(N) == 0 local cuatro_celdas = 0
                    else {
                        quietly summarize registros if `atributo' == `c' & post == `periodo' & treatment_`b' == `tratado', meanonly
                        local registros = r(mean)
                        quietly summarize lotes if `atributo' == `c' & post == `periodo' & treatment_`b' == `tratado', meanonly
                        local lotes = r(mean)
                        quietly summarize barrios if `atributo' == `c' & post == `periodo' & treatment_`b' == `tratado', meanonly
                        local barrios = r(mean)
                    }
                    post `ps' (`b') (`c') (`periodo') (`tratado') (`registros') (`lotes') (`barrios')
                }
            }
            local soporte_`c' = `cuatro_celdas'
        }
        restore
        foreach c of local categorias {
            local contraste "treat"
            local estimable = `soporte_`c''
            if `c' != `base' {
                local contraste "treat + `c'.`atributo'#c.treat"
                * No presentar como efecto propio un término omitido.
                capture scalar se_interaccion = _se[`c'.`atributo'#c.treat]
                if _rc local estimable = 0
                else if se_interaccion == 0 local estimable = 0
            }
            if _se[treat] == 0 local estimable = 0
            if `estimable' {
                quietly lincom `contraste'
                post `pr' (`b') (`c') ("efecto_total") (1) ///
                    (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n') (`g')
                if `c' != `base' {
                    quietly lincom `c'.`atributo'#c.treat
                    post `pr' (`b') (`c') ("diferencia_base") (1) ///
                        (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n') (`g')
                }
            }
            else post `pr' (`b') (`c') ("efecto_total") (0) (.) (.) (.) (.) (.) (`n') (`g')
        }
        drop treat muestra
    }
    postclose `pr'
    postclose `ps'
    use `resultados', clear
    gen double cambio_pct = 100 * (exp(b) - 1)
    gen double cambio_li = 100 * (exp(li) - 1)
    gen double cambio_ls = 100 * (exp(ls) - 1)
    export delimited using "`results_dir'/atributos_`etapa'_coef.csv", replace
    use `soporte', clear
    export delimited using "`results_dir'/atributos_`etapa'_soporte.csv", replace
}

*---------
* Prueba conjunta de las diferencias posteriores entre categorías
*---------

if "`etapa'" == "contrastes" {
    tempfile pruebas
    tempname pp
    postfile `pp' str10 atributo int buffer double F p df df_r long n barrios using `pruebas', replace
    foreach tipo in destino estrato {
        local atributo destino2018
        local base = 2
        local maximo = 7
        if "`tipo'" == "estrato" {
            local atributo estrato2018
            local base = 1
            local maximo = 6
        }
        foreach b in 400 800 1200 {
            estimates use "`results_dir'/atributos_`tipo'_`b'.ster"
            local diferencias
            forvalues c = 1/`maximo' {
                if `c' != `base' {
                    capture scalar se_interaccion = _se[`c'.`atributo'#c.treat]
                    if !_rc {
                        if se_interaccion > 0 local diferencias `diferencias' `c'.`atributo'#c.treat
                    }
                }
            }
            assert "`diferencias'" != ""
            quietly test `diferencias'
            post `pp' ("`tipo'") (`b') (r(F)) (r(p)) (r(df)) (r(df_r)) (e(N)) (e(N_clust))
        }
    }
    postclose `pp'
    use `pruebas', clear
    export delimited using "`results_dir'/atributos_heterogeneidad_test.csv", replace
}

log close
