*==================================================
* 00_master.do
* Corre todo el paper PLMB: índices, muestra, estimaciones y figuras.
* Oct 2026.
* Paquetes: reghdfe, ftools, honestdid (Rambachan y Roth).
* Insumos: predios_robust.dta (sale de 5_robustez.do), treat_CEM.dta
* (sale de 4_analysis_cem.do), base_bogota_270221.dta y las distancias
* de ArcGIS en Datos/processed/distancias_paper.
* La corrida completa toma varias horas; 04 es el módulo más pesado.
*==================================================

clear all
set more off

*---------
* Rutas
*---------

** Se usan "/" en las rutas para que Stata no confunda "\" con escapes
global dir_0 "C:/Users/USUARIO/"
global dir_tif "${dir_0}OneDrive - Universidad de los andes/RA Andes - TIF/"
global dir_proc "${dir_tif}Datos/processed/"
global dir_dist "${dir_proc}distancias_paper/"
global dir_alex "${dir_tif}Alex/"
global dir_res "${dir_tif}Paper/resultados/"
global dir_code "${dir_0}Documents/GitHub/TIF_PLMB/Código/paper/"

capture mkdir "${dir_res}"

*---------
* Módulos
*---------

do "${dir_code}01_indices.do"
do "${dir_code}02_muestra.do"
do "${dir_code}03_promedio.do"
do "${dir_code}04_gradiente.do"
do "${dir_code}05_moderadores.do"
do "${dir_code}06_atributos.do"
do "${dir_code}07_cem.do"
do "${dir_code}08_ofertas.do"
do "${dir_code}09_figuras.do"
