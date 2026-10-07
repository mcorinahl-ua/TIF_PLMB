*==================================================
* 01_indices.do
* Índices urbanos por manzana: distancia al trazado, accesibilidad
* estructural (A_std), acceso económico, distancia al CBD y equipamientos.
* Oct 2026. Viene de 7_centralidades.do (secciones 1 a 6), solo con lo
* que usa el paper. Correr desde 00_master.do.
*==================================================

clear all
set more off
cap log close
log using "${dir_res}01_indices.log", text replace

*---------
* Distancias de ArcGIS
*---------

** Distancia al CBD (Calle 72 con Carrera 7)
import delim "${dir_dist}Distancias_Manzanas-CBD.csv", clear
tostring man_codigo, replace
replace man_codigo = "00" + man_codigo if strlen(man_codigo) == 7
ren total_leng dist_cbd
keep man_codigo dist_cbd
tempfile cbd
save `cbd'

** Distancia al trazado de la PLMB. En este archivo los códigos ya están bien
import delim "${dir_dist}Distancias_Manzanas-TrazadoPLMB.csv", clear
cap ren total_length dist_plmb
cap ren total_leng dist_plmb
keep man_codigo dist_plmb
tempfile plmb
save `plmb'

** Base de manzanas de Álex (distancias a redes, empleo y equipamientos)
use "${dir_alex}base_bogota_270221.dta", clear
merge 1:1 man_codigo using `cbd', nogen keep(master match)
merge 1:1 man_codigo using `plmb', nogen keep(master match)

/*
En 7_centralidades.do (con m:1):
CBD:  38,535 pegan, 583 sin distancia
PLMB: 37,850 pegan, 1,268 sin distancia
*/

*---------
* Accesibilidad estructural
*---------

** PC1 de siete distancias de red. Los ceros son distancias válidas, por eso
** -log(1+d) y no inversos. Se orienta para que suba con la cercanía a TM.
local red dist_sitp dist_alime dist_trans dist_vart dist_vinte dist_vtron dist_vloc
foreach var of local red {
    gen double a_`var' = -ln(1 + `var')
}

pca a_dist_sitp a_dist_alime a_dist_trans a_dist_vart a_dist_vinte a_dist_vtron a_dist_vloc
predict double A_pc1 if e(sample), score
matrix cargas = e(L)
matrix valores = e(Ev)
local n_pca = e(N)
local valor_propio = valores[1, 1]

quietly correlate A_pc1 a_dist_trans
local signo = cond(r(rho) < 0, -1, 1)
replace A_pc1 = `signo' * A_pc1
egen double A_std = std(A_pc1)
label var A_std "Accesibilidad estructural (PC1, estandarizada por manzana)"

** Cargas del PC1 para la tabla A1
preserve
clear
set obs 7
gen str12 insumo = ""
gen double carga = .
local i = 0
foreach var of local red {
    local ++i
    replace insumo = "`var'" in `i'
    replace carga = `signo' * cargas[`i', 1] in `i'
}
gen double valor_propio = `valor_propio'
gen double varianza_pct = 100 * `valor_propio' / 7
gen long manzanas = `n_pca'
export delimited using "${dir_res}A_cargas.csv", replace
restore

*---------
* Acceso económico
*---------

** Empleo de la manzana por un índice de inversos de distancia vial
foreach var in dist_vtron dist_vloc dist_vinte {
    replace `var' = . if `var' <= 0
    gen inv_`var' = 1 / `var'
    egen z_inv_`var' = std(inv_`var')
}
egen transport_access = rowmean(z_inv_dist_vtron z_inv_dist_vloc z_inv_dist_vinte)
gen economic_access = log(1 + tot_emp_mz) * transport_access
label var economic_access "Acceso a oportunidades económicas"

*---------
* Centralidad y equipamientos
*---------

gen ln_dist_cbd = log(dist_cbd)
label var ln_dist_cbd "Log distancia al CBD"

local equip dist_educa dist_salud dist_entre dist_eqrec dist_eqpar
foreach var of local equip {
    replace `var' = . if `var' <= 0
    gen inv_`var' = 1 / `var'
    egen z_`var' = std(inv_`var')
}
egen amenities_index = rowmean(z_dist_educa z_dist_salud z_dist_entre z_dist_eqrec z_dist_eqpar)
label var amenities_index "Acceso a equipamientos"

ren man_codigo mancodigo
keep mancodigo dist_plmb A_std economic_access ln_dist_cbd amenities_index
isid mancodigo
save "${dir_proc}manzanas_paper.dta", replace

log close
