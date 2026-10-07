* Este archivo conserva I_AccB de la consultoría. No usar sus resultados
* para el paper sin reestimar la heterogeneidad con A_std de 7_centralidades.do.

/*==================================================
Name:           9_heter_access.do

Project:        Heterogeneous treatment effects by land use and stratum,
                conditional on urban accessibility level (I_AccB / economic_access).
Author:         Maria Corina Hernandez
E-mail:         mc.hernandezl12@uniandes.edu.co

----------------------------------------------------
Creation Date:  Mar 2026
Input:          predios_proc_ai2.dta   (built in 6_nueva_ai.do — includes
                                        dest_cat_pre, estr_pre, treat)
                manzanas_access.dta    (built in 7_centralidades.do — includes
                                        I_AccB, economic_access, access_group)
Output:         DID_heter_dest_access.docx
                DID_heter_estr_access.docx

SPECIFICATION NOTE:
    Binary treatment (treat = buffer × post-2019) captures an average effect
    within a geographic zone. This file adds urban accessibility as a third
    dimension to the heterogeneity analysis, asking:

        "Does the differential treatment effect by land use (or stratum)
         vary with the parcel's pre-existing urban accessibility?"

    Two specs per heterogeneity dimension:
        (a) treat × dest_cat_pre × accb_group  (discrete quintiles of I_AccB)
        (b) treat × dest_cat_pre × I_AccB      (continuous — linear gradient)

    The quintile spec is recommended for presentation in tables/figures because
    its coefficients are directly interpretable as ATTs within accessibility bins.
    The continuous spec is more parsimonious and a cleaner test of linearity.

    Accessibility measure used: I_AccB (PCA-based composite index from
    7_centralidades.do). As a robustness check, economic_access (simple inverse-
    distance weighted average) can be substituted — the variable is already in
    manzanas_access.dta.
==================================================*/

/*==================================================
              0: Program set up
==================================================*/

clear all
set more off

** Path
** NOTE: Only one global dir_0 is set here.
** Files 2, 3_heter, 4, and 5 have a duplicate line that overwrites this
** global with "C:\Users\proyecto\" — this corresponds to the Uniandes Server. 
global dir_0 "C:\Users\USUARIO\\"
//global dir_0 "C:\Users\proyecto\\"

** Data
global dir_data "${dir_0}OneDrive - Universidad de los andes\RA Andes - TIF\Datos\\"
global dir_raw  "${dir_data}raw\\"
global dir_proc "${dir_data}processed\\"
global dir_outcomes "${dir_0}Documents\GitHub\TIF_PLMB\Datos\outcomes\\"

** Required packages
** ssc install reghdfe
** ssc install outreg2
** ssc install coefplot


/*==================================================
      1: Cargar datos y pegar accesibilidad
==================================================*/

** Cargar base de predios con tratamiento y destinos ya definidos.
** Esta base fue creada por 6_nueva_ai.do e incluye:
**   - treat         (treatment × post-2019, nueva AI)
**   - dest_cat_pre  (destino económico fijado al periodo pre-tratamiento)
**   - estr_pre      (estrato socioeconómico fijado al periodo pre-tratamiento)
**   - ln_avaluo_real_2014, ln_avaluo_com_2014
use "${dir_proc}predios_proc_ai2.dta", clear

** Pegar índices de accesibilidad construidos en 7_centralidades.do.
** manzanas_access contiene: I_AccB, economic_access, economic_access_gr,
**   economic_access_exp, access_group, ln_dist_cbd, cbd_group, amenities_index.

** ADVERTENCIA: la variable mancodigo en predios_proc_ai2 y en manzanas_access tiene 9 dígitos (c_barrio 6 + c_manzana 3). Esto no corresponde con otros archivos de código de este repositorio, donde se usa mancodigo con 8 dígitos en total. 
** Verificar la tasa de match. Si es baja, corregir la longitud de c_manzana en
** 7_centralidades.do (cambiar -2 por -3 o viceversa).

merge m:1 mancodigo using "${dir_proc}manzanas_access.dta", gen(m_access)

** Verificar tasa de merge
tab m_access
** Idealmente casi todo debería quedar en m_access==3.
** Si hay muchos m_access==1 (solo en predios), revisar nota técnica arriba.

drop if m_access == 2   // manzanas en accesibilidad sin predios correspondientes
drop m_access


/*==================================================
      2: Preparar variables de heterogeneidad
==================================================*/

** Excluir predios públicos y vías
drop if inlist(descripcion_destino, ///
    "VIAS", "ESPACIO PÚBLICO", "LOTE DEL ESTADO", ///
    "DOTACIONAL PÚBLICO", "RECREACIONAL PÚBLICO", ///
    "NO URBANIZ/SUELO PROTEG", "TIERRAS IMPRODUCTIVAS")

** Excluir predios de destino agrícola (categoría 1 en dest_cat_pre)
drop if dest_cat_pre == 1

** Excluir observaciones sin accesibilidad (manzanas sin match)
drop if missing(I_AccB)

** Crear quintiles de I_AccB para especificaciones discretas
** (access_group en manzanas_access está basado en economic_access, no I_AccB)
xtile accb_group = I_AccB, nq(5)

label define accbp ///
    1 "Q1 – Menor accesibilidad" ///
    2 "Q2" ///
    3 "Q3" ///
    4 "Q4" ///
    5 "Q5 – Mayor accesibilidad"
label values accb_group accbp

** Estandarizar I_AccB para facilitar la interpretación de los coeficientes continuos
** (el coeficiente de la interacción se interpreta como el efecto de un incremento
**  de 1 desviación estándar en accesibilidad sobre el ATT)
egen I_AccB_std = std(I_AccB)
label var I_AccB_std "I_AccB estandarizado (media 0, sd 1)"

** Verificar distribución de accesibilidad por grupo de tratamiento
** (confirmar que no hay desequilibrio sistemático pre-tratamiento)
bys treatment: sum I_AccB if year < 2019


/*==================================================
      3: Heterogeneidad Destino Económico × Accesibilidad
==================================================*/

/*
  La interacción triple c.treat##i.dest_cat_pre##i.accb_group captura si el efecto
  diferencial del metro sobre cada tipo de destino económico varía según el nivel
  de accesibilidad previo del predio.

  Si el efecto sobre predios comerciales (dest_cat_pre==3) se concentra solo en 
  zonas de alta accesibilidad (Q4-Q5), la base imponible TIF
  es más estrecha de lo que el ATT promedio sugiere.

  Base de comparación:
    - dest_cat_pre: categoría 2 (Residencial) como base implícita
    - accb_group:   Q1 (menor accesibilidad) como base implícita
*/

*--- (a) Quintiles de accesibilidad (especificación discreta — recomendada para tablas)

#d;
    reghdfe ln_avaluo_real_2014
        c.treat##i.dest_cat_pre##i.accb_group,
        a(codigo_lote year)
        vce(cluster codigo_barrio);
#d cr
estimates store did_dest_acc_q

outreg2 using "${dir_outcomes}DID_heter_dest_access.docx", word ///
    keep(treat ///
         1.dest_cat_pre#c.treat 2.dest_cat_pre#c.treat ///
         3.dest_cat_pre#c.treat 4.dest_cat_pre#c.treat ///
         5.dest_cat_pre#c.treat 6.dest_cat_pre#c.treat 7.dest_cat_pre#c.treat ///
         2.accb_group#c.treat 3.accb_group#c.treat ///
         4.accb_group#c.treat 5.accb_group#c.treat) ///
    replace ctitle("Dest × Acc quintiles")

*--- (b) Accesibilidad continua estandarizada

#d;
    reghdfe ln_avaluo_real_2014
        c.treat##i.dest_cat_pre##c.I_AccB_std,
        a(codigo_lote year)
        vce(cluster codigo_barrio);
#d cr
estimates store did_dest_acc_c

outreg2 using "${dir_outcomes}DID_heter_dest_access.docx", word ///
    keep(treat ///
         1.dest_cat_pre#c.treat 2.dest_cat_pre#c.treat ///
         3.dest_cat_pre#c.treat 4.dest_cat_pre#c.treat ///
         5.dest_cat_pre#c.treat 6.dest_cat_pre#c.treat 7.dest_cat_pre#c.treat ///
         c.I_AccB_std#c.treat ///
         1.dest_cat_pre#c.I_AccB_std#c.treat ///
         3.dest_cat_pre#c.I_AccB_std#c.treat ///
         4.dest_cat_pre#c.I_AccB_std#c.treat ///
         5.dest_cat_pre#c.I_AccB_std#c.treat) ///
    append ctitle("Dest × Acc continua")

** Robustez: reemplazar I_AccB_std por economic_access para comparar con access_group
** standardize economic_access si se usa como continua
// egen econ_access_std = std(economic_access)
// reghdfe ln_avaluo_real_2014 c.treat##i.dest_cat_pre##c.econ_access_std, ...


/*==================================================
      4: Heterogeneidad Estrato × Accesibilidad
             (Solo predios Residenciales)
==================================================*/

/*
  La interacción triple c.treat##i.estr_pre##i.accb_group (o continua) permite
  responder si el efecto del metro sobre vivienda de estrato bajo vs alto depende
  de la accesibilidad preexistente del barrio

  Esto evalúa si el TIF captura plusvalía en zonas de estratos bajos con baja 
  accesibilidad — que sería la pregunta de equidad del instrumento.

  Restricción: solo predios con dest_cat_pre==2 (Residencial), para aislar el
  efecto sobre vivienda del efecto del mix de usos.
  Base: estrato 6 recodificado a 0 (mismo criterio que 3_analysis_did_heter.do).
*/

preserve

** Mantener solo residencial
keep if dest_cat_pre == 2

** Excluir predios con estrato 0 (sin clasificar) y recodificar base a estrato 6
drop if estr_pre == 0
replace estr_pre = 0 if estr_pre == 6   // base = estrato 6

*--- (a) Quintiles de accesibilidad (discreta)

#d;
    reghdfe ln_avaluo_real_2014
        c.treat##i.estr_pre##i.accb_group,
        a(codigo_lote year)
        vce(cluster codigo_barrio);
#d cr
estimates store did_estr_acc_q

outreg2 using "${dir_outcomes}DID_heter_estr_access.docx", word ///
    keep(treat ///
         1.estr_pre#c.treat 2.estr_pre#c.treat 3.estr_pre#c.treat ///
         4.estr_pre#c.treat 5.estr_pre#c.treat ///
         2.accb_group#c.treat 3.accb_group#c.treat ///
         4.accb_group#c.treat 5.accb_group#c.treat) ///
    replace ctitle("Estrato × Acc quintiles – Residencial")

*--- (b) Accesibilidad continua estandarizada

#d;
    reghdfe ln_avaluo_real_2014
        c.treat##i.estr_pre##c.I_AccB_std,
        a(codigo_lote year)
        vce(cluster codigo_barrio);
#d cr
estimates store did_estr_acc_c

outreg2 using "${dir_outcomes}DID_heter_estr_access.docx", word ///
    keep(treat ///
         1.estr_pre#c.treat 2.estr_pre#c.treat 3.estr_pre#c.treat ///
         4.estr_pre#c.treat 5.estr_pre#c.treat ///
         c.I_AccB_std#c.treat ///
         1.estr_pre#c.I_AccB_std#c.treat ///
         2.estr_pre#c.I_AccB_std#c.treat ///
         3.estr_pre#c.I_AccB_std#c.treat ///
         4.estr_pre#c.I_AccB_std#c.treat ///
         5.estr_pre#c.I_AccB_std#c.treat) ///
    append ctitle("Estrato × Acc continua – Residencial")

restore


/*==================================================
      5: Gráficos de coeficientes — ATT por
         quintil de accesibilidad, dentro de cada
         destino económico (visualización alternativa)
==================================================*/

/*
  En lugar de publicar la tabla de la interacción triple completa (difícil de leer),
  se grafica el ATT del tratamiento para cada combinación
  (dest_cat_pre × accb_group) usando marginsplot o coefplot por submuestra.

  La estrategia de submuestras (una regresión por quintil de accesibilidad) es
  equivalente en términos de estimación puntual a la interacción triple si no se
  imponen restricciones de homoscedasticidad entre quintiles, y es más fácil de
  presentar visualmente.
*/

forvalues q = 1/5 {

    #d;
        reghdfe ln_avaluo_real_2014
            c.treat##i.dest_cat_pre
            if accb_group == `q',
            a(codigo_lote year)
            vce(cluster codigo_barrio);
    #d cr
    estimates store did_dest_q`q'

}

** Gráfico combinado: ATT por destino económico en cada quintil de accesibilidad
coefplot ///
    (did_dest_q1, label("Q1 – Menor accesibilidad")) ///
    (did_dest_q2, label("Q2")) ///
    (did_dest_q3, label("Q3")) ///
    (did_dest_q4, label("Q4")) ///
    (did_dest_q5, label("Q5 – Mayor accesibilidad")), ///
    keep(*#c.treat) ///
    vertical yline(0) ///
    title("ATT por destino económico y quintil de accesibilidad") ///
    ytitle("Efecto tratamiento (log avalúo real 2014)") ///
    legend(rows(2)) ///
    name(dest_acc_plot, replace)

graph export "${dir_outcomes}DiD_heter_dest_access.pdf", replace


exit
/* End of do-file */

><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

Notes:
1. El modelo en este archivo hereda el grupo de tratamiento de predios_proc_ai2.dta
   (nueva área de influencia, definida en 6_nueva_ai.do). Si se desea aplicar la
   misma lógica al grupo de tratamiento original (buffer 1200m), reemplazar:
   use "${dir_proc}predios_proc.dta" y reconstruir dest_cat_pre, estr_pre, y treat.

2. La variable accb_group aquí creada es distinta de access_group en manzanas_access.dta:
   accb_group es sobre I_AccB (PCA), access_group es sobre economic_access (promedio simple).

3. Si el merge con manzanas_access.dta tiene baja tasa de match, verificar la longitud
   de mancodigo en predios_proc_ai2 (8 chars) vs manzanas_access (posiblemente 9 chars).
   Corregir en 7_centralidades.do: cambiar substr(...,-2,.) por substr(...,-3,.) en c_manzana.

Version Control:
