*==================================================
* 12_comparar_postM.do
* Resume las dos versiones de moderación estimadas en 10_paper.do.
* La fila total de cada quintil suma el efecto base y su interacción.
* 2 Oct 2026. Argumento opcional: carpeta con archivos .ster.
*==================================================

clear all
set more off
args results_dir
if "`results_dir'" == "" local results_dir "C:\Users\USUARIO\Documents\GitHub\TIF_PLMB\Datos\outcomes\paper"

tempfile resumen
tempname ph
postfile `ph' str25 moderador str12 version str18 termino byte quintil ///
    double b se p li ls long n using `resumen', replace

*---------
* Moderadores continuos
*---------

foreach m in economic_access economic_access_gr economic_access_exp ///
    ln_dist_cbd amenities_index A_std {
    forvalues v = 0/1 {
        local version "original"
        local suf ""
        if `v' == 1 {
            local version "postM"
            local suf "_postM"
        }
        estimates use "`results_dir'\zona_`m'`suf'.ster"
        local n = e(N)
        quietly lincom c.treat#c.`m'
        post `ph' ("`m'") ("`version'") ("tratamiento_x_M") (0) ///
            (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n')
        if `v' == 1 {
            quietly lincom c.post#c.`m'
            post `ph' ("`m'") ("`version'") ("post_x_M") (0) ///
                (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n')
        }
    }
}

*---------
* Efectos totales y diferencias frente al quintil 1
*---------

foreach m in access_group cbd_group {
    forvalues v = 0/1 {
        local version "original"
        local suf ""
        if `v' == 1 {
            local version "postM"
            local suf "_postM"
        }
        estimates use "`results_dir'\zona_`m'`suf'.ster"
        local n = e(N)
        quietly lincom treat
        post `ph' ("`m'") ("`version'") ("total") (1) ///
            (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n')
        forvalues q = 2/5 {
            quietly lincom treat + `q'.`m'#c.treat
            post `ph' ("`m'") ("`version'") ("total") (`q') ///
                (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n')
            quietly lincom `q'.`m'#c.treat
            post `ph' ("`m'") ("`version'") ("diferencia_Q1") (`q') ///
                (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n')
        }
    }
}

postclose `ph'
use `resumen', clear
export delimited using "`results_dir'\comparacion_postM.csv", replace

*---------
* Sensibilidad a la definición espacial de tratamiento
*---------

tempfile resumen_buffers
tempname pb
postfile `pb' int buffer str25 moderador str12 version str18 termino ///
    double b se p li ls long n using `resumen_buffers', replace

foreach b in 400 800 1200 {
    estimates use "`results_dir'\buffer_`b'.ster"
    local n = e(N)
    quietly lincom treat_`b'
    post `pb' (`b') ("sin_moderador") ("original") ("tratamiento") ///
        (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n')
    foreach m in economic_access ln_dist_cbd amenities_index {
        forvalues v = 0/1 {
            local version "original"
            local suf ""
            if `v' == 1 {
                local version "postM"
                local suf "_postM"
            }
            estimates use "`results_dir'\buffer_`b'_`m'`suf'.ster"
            local n = e(N)
            quietly lincom c.treat_`b'#c.`m'
            post `pb' (`b') ("`m'") ("`version'") ("tratamiento_x_M") ///
                (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n')
            if `v' == 1 {
                quietly lincom c.post#c.`m'
                post `pb' (`b') ("`m'") ("`version'") ("post_x_M") ///
                    (r(estimate)) (r(se)) (r(p)) (r(lb)) (r(ub)) (`n')
            }
        }
    }
}

postclose `pb'
use `resumen_buffers', clear
export delimited using "`results_dir'\comparacion_buffers_postM.csv", replace
