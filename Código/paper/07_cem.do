*==================================================
* 07_cem.do
* Comparación emparejada (CEM) de 800 m con los pesos de 2018 que guardó
* 4_analysis_cem.do: DiD con y sin pesos, prueba previa, gradiente con
* A, retención, concentración de pesos y balance.
* Oct 2026. Correr desde 00_master.do. Requiere reghdfe.
* No se vuelve a emparejar: los pesos vienen de treat_CEM.dta.
*==================================================

clear all
set more off
cap log close
log using "${dir_res}07_cem.log", text replace

*---------
* Pesos guardados
*---------

** treatment en treat_CEM.dta es el buffer de 800 m (verificado el
** 6 Oct 2026; treatment_ y treatment1 son otros buffers)
#d ;
use codigo_lote codigo_construccion codigo_resto treatment cem_matched cem_weights
    using "${dir_proc}treat_CEM.dta", clear;
#d cr
keep if cem_matched == 1
isid codigo_lote codigo_construccion codigo_resto
drop cem_matched
tempfile pesos
save `pesos'

*---------
* Muestra común emparejada
*---------

#d ;
use codigo_lote codigo_construccion codigo_resto year codigo_barrio c_barrio c_manzana
    descripcion_destino ln_avaluo_real_2014 treatment_800
    using "${dir_proc}predios_robust.dta", clear;

keep if !inlist(descripcion_destino, "VIAS", "ESPACIO PÚBLICO", "LOTE DEL ESTADO",
    "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO") & !missing(ln_avaluo_real_2014);
#d cr
drop descripcion_destino
gen str9 mancodigo = c_barrio + "0" + c_manzana
drop c_barrio c_manzana
merge m:1 mancodigo using "${dir_proc}manzanas_paper.dta", keep(match) nogen
keep if !missing(dist_plmb, A_std, economic_access, ln_dist_cbd, amenities_index) & dist_plmb >= 0
drop mancodigo economic_access ln_dist_cbd amenities_index

merge m:1 codigo_lote codigo_construccion codigo_resto using `pesos', keep(master match)
assert treatment == treatment_800 if _merge == 3

preserve
gen byte comunes = 1
gen byte emparejados = _merge == 3
collapse (sum) comunes emparejados, by(year)
export delimited using "${dir_res}cem_cobertura.csv", replace
restore

keep if _merge == 3
drop _merge treatment codigo_construccion codigo_resto
gen byte post = year >= 2019
gen byte treat = post & treatment_800 == 1

*---------
* DiD con y sin pesos
*---------

tempname pr
tempfile resultados
postfile `pr' str16 modelo str8 termino double b se p li ls long n barrios using `resultados', replace

reghdfe ln_avaluo_real_2014 treat, ///
    absorb(codigo_lote year) vce(cluster codigo_barrio) poolsize(1) compact
estimates save "${dir_res}cem_sin_pesos.ster", replace
quietly lincom treat
post `pr' ("sin_pesos") ("treat") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N)) (e(N_clust))

reghdfe ln_avaluo_real_2014 treat [aw=cem_weights], ///
    absorb(codigo_lote year) vce(cluster codigo_barrio) poolsize(1) compact
estimates save "${dir_res}cem_pesos.ster", replace
quietly lincom treat
post `pr' ("pesos") ("treat") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N)) (e(N_clust))

** Gradiente con A, en las mismas unidades del modelo principal
gen double post_q = post / (dist_plmb + 1000)
gen double post_a = post * A_std
gen double post_qa = post_q * A_std
#d ;
reghdfe ln_avaluo_real_2014 post_q post_a post_qa [aw=cem_weights],
    absorb(codigo_lote year) vce(cluster codigo_barrio)
    poolsize(1) compact;
#d cr
estimates save "${dir_res}cem_gradiente.ster", replace
foreach v in post_q post_a post_qa {
    quietly lincom `v'
    post `pr' ("gradiente") ("`v'") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N)) (e(N_clust))
}
local d = 1/1400 - 1/1800
forvalues a = 0/1 {
    quietly lincom `d' * (post_q + `a' * post_qa)
    post `pr' ("gradiente") ("A`a'") (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (e(N)) (e(N_clust))
}
postclose `pr'
preserve
use `resultados', clear
gen double cambio_pct = 100 * (exp(b) - 1)
gen double cambio_li = 100 * (exp(li) - 1)
gen double cambio_ls = 100 * (exp(ls) - 1)
export delimited using "${dir_res}cem.csv", replace
restore

*---------
* Prueba previa con pesos
*---------

keep if year <= 2018
local eventos
foreach yy of numlist 2014/2017 {
    gen byte t`yy' = year == `yy' & treatment_800 == 1
    local eventos `eventos' t`yy'
}
reghdfe ln_avaluo_real_2014 `eventos' [aw=cem_weights], ///
    absorb(codigo_lote year) vce(cluster codigo_barrio) poolsize(1) compact
estimates save "${dir_res}cem_previos.ster", replace

tempname pp
tempfile previos
postfile `pp' str16 prueba double F p df df_r long n barrios using `previos', replace
test `eventos'
post `pp' ("cero_previos") (r(F)) (r(p)) (r(df)) (r(df_r)) (e(N)) (e(N_clust))
test (t2014 = t2015) (t2015 = t2016) (t2016 = t2017)
post `pp' ("igualdad_previos") (r(F)) (r(p)) (r(df)) (r(df_r)) (e(N)) (e(N_clust))
postclose `pp'
preserve
use `previos', clear
export delimited using "${dir_res}cem_previos.csv", replace
restore

*---------
* Retención, concentración de pesos y balance en la cohorte de 2018
*---------

#d ;
use codigo_lote codigo_barrio treatment cem_matched cem_weights
    codigo_estrato area_terreno area_construida max_num_piso
    dest_residencial dest_comercial dest_industrial dest_urban_noedif
    dest_dotac dest_otros dist_cbd dist_tm n_constr_lote
    using "${dir_proc}treat_CEM.dta", clear;
#d cr

** Retención por grupo
preserve
egen byte lote = tag(treatment cem_matched codigo_lote)
egen byte barrio = tag(treatment cem_matched codigo_barrio)
gen byte registro = 1
collapse (sum) registros=registro lotes=lote barrios=barrio, by(treatment cem_matched)
export delimited using "${dir_res}cem_retencion.csv", replace
restore

** Concentración de pesos (conteo de Kish), por registro y por barrio
tempname pw
tempfile concentracion
postfile `pw' byte treatment long registros barrios double peso_max n_kish barrios_kish using `concentracion', replace
forvalues t = 0/1 {
    preserve
    keep if treatment == `t' & cem_matched == 1
    local n = _N
    gen double peso2 = cem_weights^2
    quietly summarize cem_weights
    local suma = r(sum)
    local maximo = r(max)
    quietly summarize peso2
    local kish = `suma'^2 / r(sum)
    collapse (sum) peso_barrio=cem_weights, by(codigo_barrio)
    local g = _N
    gen double peso2 = peso_barrio^2
    quietly summarize peso2
    post `pw' (`t') (`n') (`g') (`maximo') (`kish') (`suma'^2 / r(sum))
    restore
}
postclose `pw'
preserve
use `concentracion', clear
export delimited using "${dir_res}cem_concentracion.csv", replace
restore

** Diferencias estandarizadas con la DE de la cohorte completa en las
** tres columnas
tempname pb
tempfile balance
#d ;
postfile `pb' str18 variable str12 muestra double media_control media_tratado
    diferencia_std using `balance', replace;
#d cr
local balance codigo_estrato area_terreno area_construida max_num_piso dest_residencial ///
    dest_comercial dest_industrial dest_urban_noedif dest_dotac dest_otros dist_cbd dist_tm n_constr_lote
foreach v of local balance {
    quietly summarize `v' if treatment == 0
    local var0 = r(Var)
    quietly summarize `v' if treatment == 1
    local escala = sqrt((`var0' + r(Var)) / 2)
    foreach muestra in cohorte emparejados pesos {
        local condicion "1"
        local peso
        if "`muestra'" != "cohorte" local condicion "cem_matched == 1"
        if "`muestra'" == "pesos" local peso "[aw=cem_weights]"
        forvalues t = 0/1 {
            quietly summarize `v' `peso' if treatment == `t' & `condicion'
            local media`t' = r(mean)
        }
        post `pb' ("`v'") ("`muestra'") (`media0') (`media1') ((`media1' - `media0') / `escala')
    }
}
postclose `pb'
use `balance', clear
export delimited using "${dir_res}cem_balance.csv", replace

log close
