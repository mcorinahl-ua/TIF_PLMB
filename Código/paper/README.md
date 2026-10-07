# Código del paper

Los 16 programas originales del paper se agruparon aquí el 6 de octubre de 2026 y conservaron su contenido byte por byte. El 7 de octubre se añadieron un diagnóstico CEM y un generador de figuras desde CSV, ambos en Stata. Los programas 1–9 de la consultoría permanecen en la carpeta superior.

La versión vigente usa la muestra común, `A_std`, post desde 2019, referencia 2018 y buffers de 400 y 800 m, con 1200 m como sensibilidad adicional. La narrativa, resultados y pendientes están en `Paper/estado_paper.md` de la carpeta de investigación de OneDrive. Las tablas del borrador se reconstruyen leyendo resultados guardados con `Paper/revision_2026-10-06/construir_texto.py`.

## Programas

| Archivo | Función |
|---|---|
| [10_paper.do](10_paper.do) | Primer bloque de estimaciones y figuras; se conserva para los resultados y comparaciones anteriores. |
| [11_paper_ofertas.do](11_paper_ofertas.do) | Comparación transversal de ofertas y avalúos de 2025. |
| [12_comparar_postM.do](12_comparar_postM.do) | Compara especificaciones guardadas con y sin `post × M`. |
| [13_pretrends_buffers.do](13_pretrends_buffers.do) | Diagnóstico previo de los buffers en la muestra privada inicial. |
| [14_diagnosticos_paper.do](14_diagnosticos_paper.do) | Muestra común, verificación de la agrupación, ATT, moderadores, gradiente y terciles. |
| [15_auditar_atributos.do](15_auditar_atributos.do) | Auditoría de destinos y estratos de 2018. |
| [16_heterogeneidad_atributos.do](16_heterogeneidad_atributos.do) | Atributos de cada registro en 2018; modelos y contrastes por destino y estrato. |
| [17_revisar_cem.do](17_revisar_cem.do) | Verifica y reutiliza los pesos CEM existentes; estima comparación y prueba previa. |
| [18_pretrends_atributos.do](18_pretrends_atributos.do) | Pruebas previas por atributos, con la reparación numérica de estratos. |
| [19_describir_cem.do](19_describir_cem.do) | Retención, balance, concentración y reconstrucción de la partición CEM, sin nuevo matching. |
| [20_figura_gradiente.do](20_figura_gradiente.do) | Figura del gradiente desde la estimación guardada. |
| [21_descriptivos_paper.do](21_descriptivos_paper.do) | Descriptivos sobre los registros originales de 2018. |
| [22_sensibilidad_gradiente.do](22_sensibilidad_gradiente.do) | Sensibilidad a offsets de 500 y 2000 m; reutiliza 1000 m. |
| [23_patron_previos.do](23_patron_previos.do) | Contrasta coeficientes anteriores leyendo modelos guardados. |
| [24_gradiente_temporal.do](24_gradiente_temporal.do) | Modelo anual continuo; la etapa `resultados` reutiliza el modelo guardado. |
| [25_sensibilidad_temporal.do](25_sensibilidad_temporal.do) | HonestDiD a partir de coeficientes y covarianza guardados. |
| [26_gradiente_cem.do](26_gradiente_cem.do) | Único ajuste adicional: gradiente continuo con los pesos CEM existentes de 800 m. |
| [27_figuras_paper.do](27_figuras_paper.do) | Genera event study promedio y gráfico de sensibilidad desde CSV con Stata nativo, sin estimar. |

## Consultar o reconstruir productos guardados

Todos aceptan la carpeta de resultados como primer argumento; se conservaron sus rutas predeterminadas. El bloque vigente usa:

```stata
local resultados "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Paper/stata_results/diagnosticos_2026-10-06"
local codigo "C:/Users/USUARIO/Documents/GitHub/TIF_PLMB/Código/paper"

* Estas llamadas reutilizan resultados guardados; no ajustan el panel.
do "`codigo'/14_diagnosticos_paper.do" "`resultados'" figuras en
do "`codigo'/20_figura_gradiente.do" "`resultados'"
do "`codigo'/24_gradiente_temporal.do" "`resultados'" resultados
```

Esas llamadas vuelven a exportar sus productos. Para revisar los resultados basta abrir los CSV y las figuras existentes. El orden de reconstrucción completa está en `Paper/diagnosticos_paper_2026-10-06.md`; contiene etapas de preparación y estimación costosas y no se ejecutó durante la limpieza.

Se conservan las bases originales y procesadas, las cachés de muestra y atributos, los pesos CEM, los marcadores de verificación y todos los `.ster`, también los de corridas anteriores. Las copias exactas ejecutadas y sus lanzadores están en `Paper/archivo/2026-10-06/ejecuciones_y_notas.zip`; `inventario.csv` documenta las ubicaciones y hashes. El archivo histórico conserva las rutas originales de esas ejecuciones; para restaurarlas se siguen las indicaciones de su `README.md`.

## Figuras añadidas el 7 de octubre

En Stata, sin paquetes adicionales, ejecutar:

```stata
local resultados "C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF/Paper/stata_results/diagnosticos_2026-10-06"
do "C:/Users/USUARIO/Documents/GitHub/TIF_PLMB/Código/paper/27_figuras_paper.do" "`resultados'"
```

Lee `pretrends_att_comun_coef.csv` y `sensibilidad_temporal_rm.csv`; produce `event_study_promedio_en.png` y `sensibilidad_temporal_en.png`, sin tocar sus fuentes. La figura temporal continua es `gradiente_temporal_interaccion.png`, ahora figura 4 del cuerpo. Para reconstruir sus CSV desde modelos guardados se usan las etapas de resultados ya indicadas; no es necesario para redibujar las dos figuras nuevas.

El módulo 26 tarda pocos minutos en la máquina usada, lee el panel procesado y los pesos verificados y guarda `cem_gradiente.ster`, dos CSV y su log. Es un diagnóstico de otra población ponderada. No repite matching ni el bloque principal. El original de Luis Ángel y los insumos de resultados se preservan; las versiones históricas están en `Paper/archivo/` de OneDrive.
