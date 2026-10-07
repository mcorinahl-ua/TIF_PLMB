*==================================================
* 17_revisar_cem.do
* Auditar y reutilizar los pesos CEM de 2018 para el buffer de 800 m.
* 6 Oct 2026. No ejecuta un nuevo emparejamiento.
* Requiere reghdfe; ejecutar 16, etapa preparar, antes de la auditoría.
* Se compara con y sin pesos sobre los mismos registros emparejados.
*==================================================

clear all
set more off
args results_dir etapa
if "${dir_proc}" == "" global dir_proc "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Datos/processed"
if "`results_dir'" == "" local results_dir "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Paper/stata_results/diagnosticos_2026-10-06"
if "`etapa'" == "" local etapa "auditar"
assert inlist("`etapa'", "auditar", "estimar")
capture log close
log using "`results_dir'/cem_`etapa'.log", text replace

*---------
* Correspondencia de llaves, pesos y tratamiento
*---------

if "`etapa'" == "auditar" {
    capture erase "`results_dir'/cem_verificado.txt"
    tempfile pesos auditoria
    tempname pa
    postfile `pa' str45 metrica double valor using `auditoria', replace
    use codigo_lote codigo_construccion codigo_resto cem_weights cem_matched cem_strata ///
        using "${dir_proc}/treat_weights.dta", clear
    isid codigo_lote codigo_construccion codigo_resto
    assert cem_matched == 1 & cem_weights > 0 & !missing(cem_weights, cem_strata)
    post `pa' ("registros_archivo_pesos") (_N)
    rename (cem_weights cem_matched cem_strata) (peso_guardado match_guardado estrato_guardado)
    save `pesos'

    * La base guardada el 13 Feb 2026 tiene treatment, no treatment_800.
    * Comparar esa variable con el buffer actual antes de aceptar los pesos.
    #d;
    use codigo_lote codigo_construccion codigo_resto treatment treatment_ treatment1
        cem_weights cem_matched cem_strata
        using "${dir_proc}/treat_CEM.dta", clear;
    #d cr
    isid codigo_lote codigo_construccion codigo_resto
    post `pa' ("registros_cohorte_cem") (_N)
    quietly count if cem_matched == 1
    post `pa' ("registros_emparejados_cem") (r(N))
    merge 1:1 codigo_lote codigo_construccion codigo_resto using `pesos'
    quietly count if _merge == 2 | (cem_matched == 1 & _merge != 3)
    local llaves_inconsistentes = r(N)
    post `pa' ("llaves_inconsistentes_pesos") (`llaves_inconsistentes')
    quietly count if _merge == 3 & (cem_weights != peso_guardado | cem_matched != match_guardado | cem_strata != estrato_guardado)
    local pesos_inconsistentes = r(N)
    post `pa' ("pesos_o_estratos_inconsistentes") (`pesos_inconsistentes')
    drop _merge peso_guardado match_guardado estrato_guardado
    merge 1:1 codigo_lote codigo_construccion codigo_resto ///
        using "`results_dir'/atributos_por_registro_2018.dta", keep(master match)
    quietly count if _merge == 3
    post `pa' ("cohorte_con_ficha_privada_2018") (r(N))
    quietly count if _merge == 3 & treatment != treatment_800_2018
    local tratamientos_distintos = r(N)
    post `pa' ("tratamientos_distintos_cohorte") (`tratamientos_distintos')
    quietly count if cem_matched == 1 & _merge == 3
    post `pa' ("emparejados_con_ficha_privada_2018") (r(N))
    quietly count if cem_matched == 1 & _merge != 3
    post `pa' ("emparejados_sin_ficha_privada_2018") (r(N))
    quietly count if cem_matched == 1 & _merge == 3 & treatment != treatment_800_2018
    post `pa' ("tratamientos_distintos_emparejados") (r(N))
    foreach v in treatment_ treatment1 {
        quietly count if _merge == 3 & `v' != treatment_800_2018
        post `pa' ("diferencias_`v'_vs_800") (r(N))
    }
    postclose `pa'
    preserve
    use `auditoria', clear
    export delimited using "`results_dir'/cem_auditoria.csv", replace
    restore
    * Una diferencia de tratamiento exige revisar el matching, no ignorarla.
    assert `llaves_inconsistentes' == 0
    assert `pesos_inconsistentes' == 0
    assert `tratamientos_distintos' == 0
    keep if cem_matched == 1 & _merge == 3
    assert !missing(cem_weights) & cem_weights > 0
    keep codigo_lote codigo_construccion codigo_resto treatment_800_2018 cem_weights
    save "`results_dir'/cem_pesos_verificados.dta", replace
    file open ok using "`results_dir'/cem_verificado.txt", write replace
    file write ok "Llaves, pesos y tratamiento de 800 m concordantes; cohorte privada de 2018." _n
    file close ok
}

*---------
* Comparar selección de muestra y ponderación
*---------

if "`etapa'" == "estimar" {
    confirm file "`results_dir'/cem_verificado.txt"
    #d;
    use codigo_lote codigo_construccion codigo_resto year codigo_barrio
        c_barrio c_manzana descripcion_destino ln_avaluo_real_2014 treatment_800
        using "${dir_proc}/predios_robust.dta", clear;
    #d cr
    keep if !inlist(descripcion_destino, "VIAS", "ESPACIO PÚBLICO", ///
        "LOTE DEL ESTADO", "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO") & !missing(ln_avaluo_real_2014)
    drop descripcion_destino
    gen str9 mancodigo = c_barrio + "0" + c_manzana
    drop c_barrio c_manzana
    #d;
    merge m:1 mancodigo using "${dir_proc}/manzanas_access.dta",
        keep(master match) keepusing(dist_plmb A_std A_rank
        economic_access ln_dist_cbd amenities_index);
    #d cr
    keep if !missing(dist_plmb, A_std, A_rank, economic_access, ln_dist_cbd, amenities_index) & dist_plmb >= 0
    drop _merge mancodigo dist_plmb A_std A_rank economic_access ln_dist_cbd amenities_index
    merge m:1 codigo_lote codigo_construccion codigo_resto ///
        using "`results_dir'/cem_pesos_verificados.dta", keep(master match)
    assert treatment_800 == treatment_800_2018 if _merge == 3
    preserve
    gen byte comunes = 1
    gen byte emparejados = _merge == 3
    collapse (sum) comunes emparejados, by(year)
    export delimited using "`results_dir'/cem_cobertura.csv", replace
    restore
    keep if _merge == 3
    drop _merge treatment_800_2018 codigo_construccion codigo_resto
    gen byte post = year >= 2019
    gen byte treat = post & treatment_800 == 1

    tempfile resultados
    tempname pr
    postfile `pr' str20 modelo double b se p li ls long n barrios lotes using `resultados', replace
    reghdfe ln_avaluo_real_2014 treat, ///
        absorb(codigo_lote year) vce(cluster codigo_barrio) poolsize(1) compact
    local n_comparacion = e(N)
    local g = e(N_clust)
    gen byte muestra = e(sample)
    preserve
    keep if muestra
    bysort codigo_lote: keep if _n == 1
    local l = _N
    restore
    estimates save "`results_dir'/cem_800_sin_pesos.ster", replace
    quietly lincom treat
    post `pr' ("matched_sin_pesos") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n_comparacion') (`g') (`l')
    reghdfe ln_avaluo_real_2014 treat [aw=cem_weights], ///
        absorb(codigo_lote year) vce(cluster codigo_barrio) poolsize(1) compact
    assert e(N) == `n_comparacion'
    assert e(sample) == muestra
    local g = e(N_clust)
    estimates save "`results_dir'/cem_800_con_pesos.ster", replace
    quietly lincom treat
    post `pr' ("matched_cem") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n_comparacion') (`g') (`l')
    postclose `pr'

    * El matching no garantiza tendencias paralelas en la muestra ponderada.
    keep if year <= 2018
    local eventos
    foreach yy of numlist 2014/2017 {
        gen byte t`yy' = year == `yy' & treatment_800 == 1
        local eventos `eventos' t`yy'
    }
    reghdfe ln_avaluo_real_2014 `eventos' [aw=cem_weights], ///
        absorb(codigo_lote year) vce(cluster codigo_barrio) poolsize(1) compact
    estimates save "`results_dir'/cem_800_previos.ster", replace
    local n = e(N)
    local g = e(N_clust)
    tempfile prueba coeficientes
    tempname pp pc
    postfile `pp' double F p df df_r long n barrios using `prueba', replace
    test `eventos'
    post `pp' (r(F)) (r(p)) (r(df)) (r(df_r)) (`n') (`g')
    postclose `pp'
    postfile `pc' int year double b se p li ls using `coeficientes', replace
    foreach yy of numlist 2014/2017 {
        quietly lincom t`yy'
        post `pc' (`yy') (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub))
    }
    postclose `pc'
    use `resultados', clear
    gen double cambio_pct = 100 * (exp(b) - 1)
    export delimited using "`results_dir'/cem_comparacion.csv", replace
    use `prueba', clear
    export delimited using "`results_dir'/cem_previos_test.csv", replace
    use `coeficientes', clear
    export delimited using "`results_dir'/cem_previos_coef.csv", replace
}

log close
