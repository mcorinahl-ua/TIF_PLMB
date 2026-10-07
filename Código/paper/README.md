# Código del paper PLMB

Correr `00_master.do`. Define las rutas y llama los módulos en orden. Todos escriben en `Paper/resultados` (OneDrive): logs, `.ster`, CSV y figuras.

| Archivo | Qué hace |
|---|---|
| `00_master.do` | Rutas y orden de ejecución |
| `00_programas.do` | Programas para HonestDiD (los usan 03 y 04) |
| `01_indices.do` | Índices por manzana: A, empleo, CBD, equipamientos. Sale `manzanas_paper.dta` |
| `02_muestra.do` | Muestra común, bases lote-año, salida de lotes, correlación catastro-comercial, descriptivos 2018 |
| `03_promedio.do` | DiD y event study por buffer, HonestDiD del promedio |
| `04_gradiente.do` | Gradiente q × A (agrupado, con otros moderadores, tramo, deciles, sin lotes que salen, offsets), modelos anuales con HonestDiD y terciles |
| `05_moderadores.do` | DiD moderado por A, empleo, CBD y equipamientos; tendencias previas por moderador |
| `06_atributos.do` | Destino y estrato de 2018 (referencias: residencial y estrato 2) y sus pruebas previas |
| `07_cem.do` | CEM de 800 m con los pesos guardados |
| `08_ofertas.do` | Ofertas PH 2025 frente al avalúo |
| `09_figuras.do` | Figuras desde los CSV |

Paquetes: `reghdfe`, `ftools`, `honestdid`.

Insumos (en `Datos/processed` salvo que se diga otra cosa): `predios_robust.dta` (de `5_robustez.do`), `treat_CEM.dta` (de `4_analysis_cem.do`), `distancias_paper/` (ArcGIS) y `Alex/base_bogota_270221.dta` y `Alex/Ofertas_PH_CIB_2025.xlsx`.

Especificación: post desde 2019, 2018 de referencia en los modelos anuales, FE de lote y año, errores agrupados por barrio, cada registro catastral pesa uno. Buffers de 400 y 800 m, 1200 m como sensibilidad. Proximidad continua 1/(d + 1000).

Los programas 1–9 de la carpeta superior son de la consultoría. El código y los resultados anteriores del paper (módulos 10–27) están en `Paper/diagnosticos` de OneDrive y en la rama `respaldo-2026-10-07`.
