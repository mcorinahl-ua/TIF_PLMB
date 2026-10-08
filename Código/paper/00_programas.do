*==================================================
* 00_programas.do
* Programas para la sensibilidad de honestdid.
* Oct 2026. Los cargan 03_promedio.do y 04_gradiente.do.
*==================================================

** hd_matrices: arma beta y sigma con los coeficientes pedidos, en ese
** orden y multiplicados por escala, desde la última estimación
capture program drop hd_matrices
program define hd_matrices
    syntax namelist, escala(real)
    local k : word count `namelist'
    matrix bb = e(b)
    matrix VV = e(V)
    matrix beta = J(1, `k', .)
    matrix sigma = J(`k', `k', .)
    forvalues i = 1/`k' {
        local ci = colnumb(bb, "`: word `i' of `namelist''")
        matrix beta[1, `i'] = `escala' * bb[1, `ci']
        forvalues j = 1/`k' {
            local cj = colnumb(bb, "`: word `j' of `namelist''")
            matrix sigma[`i', `j'] = `escala'^2 * VV[`ci', `cj']
        }
    }
end

** hd_ref2017: cambia la referencia de 2018 a 2017. Entra 2014-2017 y
** 2019-2025; sale 2014-2016 y 2018-2025, con 2018 como primer año post
capture program drop hd_ref2017
program define hd_ref2017
    mata: T = I(11); T[., 4] = J(11, 1, -1); T[4, 4] = -1
    mata: st_matrix("beta", st_matrix("beta") * T')
    mata: st_matrix("sigma", T * st_matrix("sigma") * T')
end

** hd_correr: intervalos para el promedio simple de los años post y los
** agrega a archivo.dta. omitir deja en cero los primeros años post
capture program drop hd_correr
program define hd_correr
    syntax, pre(integer) post(integer) delta(string) mvec(numlist) ///
        archivo(string) objetivo(string) [omitir(integer 0)]
    local usados = `post' - `omitir'
    matrix l = J(`post', 1, 1/`usados')
    forvalues i = 1/`omitir' {
        matrix l[`i', 1] = 0
    }
    honestdid, numpre(`pre') b(beta) vcov(sigma) l_vec(l) ///
        delta(`delta') mvec(`mvec') gridPoints(1000) mata(hd_res)
    mata: st_matrix("ic", hd_res.CI)

    ** En un frame aparte para no copiar la base grande con preserve
    capture frame drop hd_tmp
    frame create hd_tmp
    frame hd_tmp {
        svmat double ic
        ren (ic1 ic2 ic3) (M inferior superior)
        gen str40 objetivo = "`objetivo'"
        gen str2 delta = "`delta'"
        capture append using "${dir_res}`archivo'.dta"
        save "${dir_res}`archivo'.dta", replace
    }
    frame drop hd_tmp
end
