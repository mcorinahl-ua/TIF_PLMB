*==================================================
* 15_auditar_atributos.do
* Revisar destinos y estratos distintos dentro del lote en 2018.
* 6 Oct 2026. Auditoría; no asigna un atributo único a cada lote.
*==================================================

clear all
set more off
args results_dir
if "${dir_proc}" == "" global dir_proc "C:\Users\USUARIO\OneDrive - Universidad de los andes\RA Andes - TIF\Datos\processed"
if "`results_dir'" == "" local results_dir "C:\Users\USUARIO\OneDrive - Universidad de los andes\RA Andes - TIF\Paper\stata_results\diagnosticos_2026-10-06"
capture mkdir "`results_dir'"
capture log close
log using "`results_dir'\auditoria_atributos.log", text replace

#d;
use codigo_lote codigo_construccion codigo_resto year codigo_estrato
    descripcion_destino ln_avaluo_real_2014
    using "${dir_proc}\predios_robust.dta", clear;
#d cr
keep if year == 2018
keep if !inlist(descripcion_destino, "VIAS", "ESPACIO PÚBLICO", ///
    "LOTE DEL ESTADO", "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO") & !missing(ln_avaluo_real_2014)
isid codigo_lote codigo_construccion codigo_resto

* Categorías del do-file anterior; la muestra aquí es la privada del ATT.
gen byte dest_cat = 7
#d;
replace dest_cat = 1 if inlist(descripcion_destino, "AGRICOLA", "AGRÍCOLA",
    "AGROPECUARIO", "PECUARIO", "FORESTAL", "PREDIO RURAL PARCEL. NO EDIFI.");
#d cr
replace dest_cat = 2 if descripcion_destino == "RESIDENCIAL"
#d;
replace dest_cat = 3 if inlist(descripcion_destino, "COMERCIO EN CORREDOR COM",
    "COMERCIO PUNTUAL", "COMERCIO EN CENTRO COMER", "PARQUEADEROS");
#d cr
replace dest_cat = 4 if inlist(descripcion_destino, "INDUSTRIAL", "AGROINDUSTRIAL")
replace dest_cat = 5 if descripcion_destino == "URBANIZADO NO EDIFICADO"
replace dest_cat = 6 if descripcion_destino == "DOTACIONAL PRIVADO"

bysort codigo_lote (dest_cat): gen byte mezcla_destino = dest_cat[1] != dest_cat[_N]
* El estrato se compara entre los registros residenciales del mismo lote.
gen byte estr_res = codigo_estrato if dest_cat == 2
bys codigo_lote: egen byte estr_min = min(estr_res)
bys codigo_lote: egen byte estr_max = max(estr_res)
gen byte mezcla_estrato = estr_min != estr_max
by codigo_lote: gen byte un_lote = _n == 1
gen byte un_registro = 1
collapse (sum) lotes=un_lote registros=un_registro, by(mezcla_destino mezcla_estrato)
export delimited using "`results_dir'\atributos_2018_auditoria.csv", replace
log close
