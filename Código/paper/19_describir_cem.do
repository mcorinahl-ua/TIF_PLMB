*==================================================
* 19_describir_cem.do
* Cobertura, balance y procedencia de los pesos CEM guardados.
* 6 Oct 2026. No ejecuta un nuevo emparejamiento ni modifica los pesos.
* Usa las funciones de cortes del paquete cem instalado.
* Contrasta 4_analysis_cem.do actual, commit 21fa624 y cem_match_log_v2.txt.
*==================================================

clear all
set more off
args results_dir
if "${dir_proc}" == "" global dir_proc "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Datos/processed"
if "`results_dir'" == "" local results_dir "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Paper/stata_results/diagnosticos_2026-10-06"
capture log close
log using "`results_dir'/cem_describir.log", text replace
#d;
use codigo_lote codigo_barrio treatment cem_matched cem_weights cem_strata
    codigo_estrato area_terreno area_construida max_num_piso
    dest_residencial dest_comercial dest_industrial dest_agricola
    dest_urban_noedif dest_dotac dest_otros dist_cbd dist_tm n_constr_lote
    dist_plmb_p dist_cbd_p dist_tm_p dist_malla_p
    using "${dir_proc}/treat_CEM.dta", clear;
#d cr
assert inlist(treatment, 0, 1) & inlist(cem_matched, 0, 1)
assert !missing(cem_strata)
assert cem_weights == 0 if cem_matched == 0
assert cem_weights > 0 & cem_weights < . if cem_matched == 1

*---------
* Registros, lotes y barrios retenidos en la cohorte de 2018
*---------

preserve
egen byte lote = tag(treatment cem_matched codigo_lote)
egen byte barrio = tag(treatment cem_matched codigo_barrio)
gen byte registro = 1
collapse (sum) registros=registro lotes=lote barrios=barrio, by(treatment cem_matched)
export delimited using "`results_dir'/cem_retencion_2018.csv", replace
restore

* Los pesos control normalizan la composición a los tratados emparejados.
quietly count if treatment == 0 & cem_matched == 1
local nc = r(N)
quietly count if treatment == 1 & cem_matched == 1
local nt = r(N)
bys cem_strata: egen long nc_estrato = total(treatment == 0)
by cem_strata: egen long nt_estrato = total(treatment == 1)
assert cem_matched == (nc_estrato > 0 & nt_estrato > 0)
gen double peso_esperado = 0
replace peso_esperado = 1 if treatment == 1 & cem_matched == 1
replace peso_esperado = (`nc'/`nt') * nt_estrato/nc_estrato if treatment == 0 & cem_matched == 1
gen double dif_peso = abs(cem_weights - peso_esperado)
quietly summarize dif_peso
local dif_max = r(max)
assert `dif_max' < 1e-8
drop nc_estrato nt_estrato peso_esperado dif_peso

tempfile pesos
tempname pw
#d;
postfile `pw' byte treatment long registros barrios
    double suma_pesos peso_max n_kish barrios_kish dif_peso_max
    using `pesos', replace;
#d cr
forvalues t = 0/1 {
    preserve
    keep if treatment == `t' & cem_matched == 1
    local n = _N
    gen double peso2 = cem_weights^2
    quietly summarize cem_weights
    local sw = r(sum)
    local wm = r(max)
    quietly summarize peso2
    local nk = `sw'^2/r(sum)
    collapse (sum) peso_barrio=cem_weights, by(codigo_barrio)
    local g = _N
    gen double peso2_barrio = peso_barrio^2
    quietly summarize peso2_barrio
    local gk = `sw'^2/r(sum)
    post `pw' (`t') (`n') (`g') (`sw') (`wm') (`nk') (`gk') (`dif_max')
    restore
}
postclose `pw'
preserve
use `pesos', clear
export delimited using "`results_dir'/cem_concentracion_pesos.csv", replace
restore

*---------
* Diferencias de medias con una escala común antes y después de CEM
*---------

tempfile balance
tempname pb
#d;
postfile `pb' str25 variable str18 muestra long n_control n_tratado
    double media_control media_tratado sd_base diferencia_estandarizada
    using `balance', replace;
#d cr
foreach v in codigo_estrato area_terreno area_construida max_num_piso ///
    dest_residencial dest_comercial dest_industrial dest_urban_noedif dest_dotac dest_otros dist_cbd dist_tm n_constr_lote {
    quietly summarize `v' if treatment == 0
    local var0 = r(Var)
    quietly summarize `v' if treatment == 1
    local escala = sqrt((`var0' + r(Var))/2)
    foreach muestra in cohorte emparejados pesos_cem {
        local condicion "1"
        local peso
        if "`muestra'" != "cohorte" local condicion "cem_matched == 1"
        if "`muestra'" == "pesos_cem" local peso "[aw=cem_weights]"
        forvalues t = 0/1 {
            quietly summarize `v' `peso' if treatment == `t' & `condicion'
            local media`t' = r(mean)
            local n`t' = r(N)
        }
        local smd = (`media1' - `media0')/`escala'
        post `pb' ("`v'") ("`muestra'") (`n0') (`n1') (`media0') (`media1') (`escala') (`smd')
    }
}
postclose `pb'
preserve
use `balance', clear
export delimited using "`results_dir'/cem_balance_2018.csv", replace
restore

*---------
* Cortes y correspondencia de particiones, sin llamar a cem
*---------

* coarsen() reproduce únicamente el corte de cada variable.
* La correspondencia se evalúa en ambas direcciones, sin depender del número
* asignado por el programa a cada estrato.
quietly findfile cem-mata.do
quietly do "`r(fn)'"
tempfile cortes particiones
tempname pc pp
postfile `pc' str25 variable str12 metodo int punto double corte using `cortes', replace
postfile `pp' str18 candidato long grupos filas_divididas filas_fusionadas using `particiones', replace
gen byte c_codigo_estrato = .
mata: st_store(., "c_codigo_estrato", coarsen(st_data(., "codigo_estrato"), (0, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5)))
local j = 0
foreach x in 0 1.5 2.5 3.5 4.5 5.5 6.5 {
    local ++j
    post `pc' ("codigo_estrato") ("explicito") (`j') (`x')
}
foreach v in area_terreno area_construida max_num_piso dest_residencial dest_comercial ///
    dest_industrial dest_agricola dest_urban_noedif dest_dotac dest_otros dist_cbd dist_tm ///
    n_constr_lote dist_plmb_p dist_cbd_p dist_tm_p dist_malla_p {
    gen int c_`v' = .
    mata: st_store(., "c_`v'", coarsen(st_data(., "`v'"), "sturges"))
    mata: st_matrix("cortes_v", rangen(min(st_data(., "`v'")), max(st_data(., "`v'")), sturges(st_data(., "`v'"))))
    forvalues j = 1/`=rowsof(cortes_v)' {
        post `pc' ("`v'") ("sturges") (`j') (cortes_v[`j', 1])
    }
}
local comunes c_codigo_estrato c_area_construida c_max_num_piso c_dest_residencial ///
    c_dest_comercial c_dest_industrial c_dest_urban_noedif c_dest_dotac c_dest_otros c_dist_cbd
foreach candidato in actual febrero13 log_v2 {
    local lista `comunes' c_n_constr_lote
    if "`candidato'" == "febrero13" local lista `lista' c_dist_tm
    if "`candidato'" == "log_v2" {
        local lista `comunes' c_area_terreno c_dest_agricola c_dist_plmb_p c_dist_cbd_p c_dist_tm_p c_dist_malla_p
    }
    egen long grupo = group(`lista'), missing
    egen byte tag_grupo = tag(grupo)
    quietly count if tag_grupo
    local ng = r(N)
    bys cem_strata (grupo): gen byte dividido = grupo[1] != grupo[_N]
    quietly count if dividido
    local nd = r(N)
    bys grupo (cem_strata): gen byte fusionado = cem_strata[1] != cem_strata[_N]
    quietly count if fusionado
    post `pp' ("`candidato'") (`ng') (`nd') (r(N))
    drop grupo tag_grupo dividido fusionado
}
postclose `pc'
postclose `pp'
use `cortes', clear
export delimited using "`results_dir'/cem_cortes_candidatos.csv", replace
use `particiones', clear
export delimited using "`results_dir'/cem_particiones.csv", replace
log close
