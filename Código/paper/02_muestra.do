*==================================================
* 02_muestra.do
* Muestra común del paper y bases lote-año para estimar.
* Oct 2026.
*
* Los regresores son constantes dentro de lote-año, así que se estima
* sobre la media del log del avalúo por lote-año con [fw = número de
* registros].
*==================================================

clear all
set more off
cap log close
log using "${dir_res}02_muestra.log", text replace

*---------
* Registros privados con avalúo
*---------

#d ;
use codigo_lote codigo_construccion codigo_resto year codigo_barrio c_barrio c_manzana
    descripcion_destino codigo_estrato ln_avaluo_real_2014 ln_avaluo_com_2014
    treatment_400 treatment_800 treatment_1200 tramo_800
    using "${dir_proc}predios_robust.dta", clear;
#d cr

** Excluimos vías, espacio público y destinos públicos
#d ;
keep if !inlist(descripcion_destino, "VIAS", "ESPACIO PÚBLICO", "LOTE DEL ESTADO",
    "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO") & !missing(ln_avaluo_real_2014);
#d cr

** Destino agrupado
gen byte destino = 7
#d ;
replace destino = 1 if inlist(descripcion_destino, "AGRICOLA", "AGRÍCOLA",
    "AGROPECUARIO", "PECUARIO", "FORESTAL", "PREDIO RURAL PARCEL. NO EDIFI.");
replace destino = 3 if inlist(descripcion_destino, "COMERCIO EN CORREDOR COM",
    "COMERCIO PUNTUAL", "COMERCIO EN CENTRO COMER", "PARQUEADEROS");
#d cr
replace destino = 2 if descripcion_destino == "RESIDENCIAL"
replace destino = 4 if inlist(descripcion_destino, "INDUSTRIAL", "AGROINDUSTRIAL")
replace destino = 5 if descripcion_destino == "URBANIZADO NO EDIFICADO"
replace destino = 6 if descripcion_destino == "DOTACIONAL PRIVADO"
label define destino 1 "Agrícola" 2 "Residencial" 3 "Comercial" 4 "Industrial" ///
    5 "Urbanizado no edificado" 6 "Dotacional privado" 7 "Otros"
label values destino destino
drop descripcion_destino

** Índices de la manzana
gen str9 mancodigo = c_barrio + "0" + c_manzana
drop c_barrio c_manzana
merge m:1 mancodigo using "${dir_proc}manzanas_paper.dta", keep(master match) nogen
gen byte comun = !missing(dist_plmb, A_std, economic_access, ln_dist_cbd, amenities_index) & dist_plmb >= 0

** Cobertura por año
preserve
gen byte privados = 1
collapse (sum) privados comun, by(year)
export delimited using "${dir_res}cobertura_muestra.csv", replace
restore

keep if comun
drop comun dist_plmb A_std economic_access ln_dist_cbd amenities_index

*---------
* Avalúo catastral frente al avalúo comercial de referencia
*---------

tempname pc
tempfile correlaciones
postfile `pc' int year double r long n using `correlaciones', replace
correlate ln_avaluo_real_2014 ln_avaluo_com_2014
post `pc' (0) (r(rho)) (r(N))
forvalues yy = 2014/2025 {
    quietly correlate ln_avaluo_real_2014 ln_avaluo_com_2014 if year == `yy'
    post `pc' (`yy') (r(rho)) (r(N))
}
postclose `pc'
preserve
use `correlaciones', clear
label var year "0 = todos los años"
export delimited using "${dir_res}correlacion_catastro_comercial.csv", replace
restore
drop ln_avaluo_com_2014

*---------
* Destino y estrato de cada registro en 2018
*---------

** Se toma la ficha del mismo lote-construcción-resto en 2018. No se le
** asigna a una ficha nueva el atributo de otra construcción del lote.
preserve
keep if year == 2018
isid codigo_lote codigo_construccion codigo_resto
keep codigo_lote codigo_construccion codigo_resto destino codigo_estrato
ren (destino codigo_estrato) (destino2018 estrato2018)
tempfile atributos
save `atributos'
restore

merge m:1 codigo_lote codigo_construccion codigo_resto using `atributos', keep(master match)
gen byte ficha2018 = _merge == 3
drop _merge destino codigo_estrato codigo_construccion codigo_resto
recast double ln_avaluo_real_2014

*---------
* Base lote-año de la muestra común
*---------

preserve
#d ;
collapse (mean) ln_avaluo_real_2014 (count) n_registros=ln_avaluo_real_2014,
    by(codigo_lote year codigo_barrio mancodigo treatment_400 treatment_800
    treatment_1200 tramo_800);
#d cr
isid codigo_lote year
recast long n_registros
merge m:1 mancodigo using "${dir_proc}manzanas_paper.dta", keep(match) nogen

gen byte post = year >= 2019
gen double prox1000 = 1 / (dist_plmb + 1000)

** Terciles de A ponderados por registros
xtile A_tercil = A_std [fw = n_registros], nq(3)

** Lotes que salen de la muestra privada después de 2018 (compras de la
** EMB, englobes o cambio a destino público)
bys codigo_lote: egen primero = min(year)
by codigo_lote: egen ultimo = max(year)
gen byte sale = primero <= 2018 & inrange(ultimo, 2018, 2024)
drop primero ultimo

tab tramo_800 treatment_800, missing
save "${dir_res}comun_lote_anio.dta", replace

** Salida de lotes presentes en 2018, por buffer
keep if year == 2018
tempname ps
tempfile salidas
postfile `ps' int buffer byte tratado long lotes salen using `salidas', replace
foreach b in 400 800 1200 {
    forvalues t = 0/1 {
        quietly count if treatment_`b' == `t'
        local lotes = r(N)
        quietly count if treatment_`b' == `t' & sale
        post `ps' (`b') (`t') (`lotes') (r(N))
    }
}
postclose `ps'
use `salidas', clear
gen double salen_pct = 100 * salen / lotes
export delimited using "${dir_res}salida_lotes.csv", replace
restore

*---------
* Base lote-año con atributos de 2018
*---------

keep if ficha2018
#d ;
collapse (mean) ln_avaluo_real_2014 (count) n_registros=ln_avaluo_real_2014,
    by(codigo_lote year codigo_barrio destino2018 estrato2018
    treatment_400 treatment_800 treatment_1200);
#d cr
recast long n_registros
gen byte post = year >= 2019
save "${dir_res}atributos_lote_anio.dta", replace

*---------
* Descriptivos de 2018 (tabla 1)
*---------

** Medias y DE sobre los registros, antes de quitar singletons
#d ;
use codigo_lote codigo_barrio c_barrio c_manzana year ln_avaluo_real_2014
    avaluo_real_2014 descripcion_destino area_construida area_terreno
    codigo_estrato max_num_piso treatment_400 treatment_800 treatment_1200
    if year == 2018 using "${dir_proc}predios_robust.dta", clear;
#d cr
#d ;
keep if !inlist(descripcion_destino, "VIAS", "ESPACIO PÚBLICO", "LOTE DEL ESTADO",
    "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO") & !missing(ln_avaluo_real_2014);
#d cr
gen str9 mancodigo = c_barrio + "0" + c_manzana
merge m:1 mancodigo using "${dir_proc}manzanas_paper.dta", keep(match) nogen
keep if !missing(dist_plmb, A_std, economic_access, ln_dist_cbd, amenities_index) & dist_plmb >= 0
count

gen double avaluo_millones = avaluo_real_2014 / 1000000
gen byte estrato_res = codigo_estrato if descripcion_destino == "RESIDENCIAL" & inrange(codigo_estrato, 1, 6)

tempfile descriptivos soporte
tempname pd ps
postfile `pd' int buffer byte tratado str25 variable long n double media sd using `descriptivos', replace
postfile `ps' int buffer byte tratado long registros lotes barrios using `soporte', replace
local variables ln_avaluo_real_2014 avaluo_millones area_construida area_terreno ///
    estrato_res max_num_piso A_std economic_access ln_dist_cbd amenities_index
foreach b in 400 800 1200 {
    egen byte tag_lote = tag(treatment_`b' codigo_lote)
    egen byte tag_barrio = tag(treatment_`b' codigo_barrio)
    forvalues t = 0/1 {
        quietly count if treatment_`b' == `t'
        local registros = r(N)
        quietly count if treatment_`b' == `t' & tag_lote
        local lotes = r(N)
        quietly count if treatment_`b' == `t' & tag_barrio
        post `ps' (`b') (`t') (`registros') (`lotes') (r(N))
        foreach v of local variables {
            quietly summarize `v' if treatment_`b' == `t'
            post `pd' (`b') (`t') ("`v'") (r(N)) (r(mean)) (r(sd))
        }
    }
    drop tag_lote tag_barrio
}
postclose `pd'
postclose `ps'
use `descriptivos', clear
export delimited using "${dir_res}descriptivos_2018.csv", replace
use `soporte', clear
export delimited using "${dir_res}descriptivos_2018_soporte.csv", replace

log close
