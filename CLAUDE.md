# TIF_PLMB — Contexto vigente

Actualizado el 7 de octubre de 2026. El repositorio conserva la consultoría histórica sobre TIF y el código del artículo actual. Para el paper, la fuente de decisiones y pendientes es `Paper/estado_paper.md` en `C:/Users/USUARIO/OneDrive - Universidad de los andes/RA Andes - TIF`. Los datos y resultados grandes viven allí, no en GitHub.

## Artículo actual

El artículo estudia capitalización anticipada y heterogeneidad espacial de los efectos del PLMB, no demuestra la viabilidad fiscal de un instrumento particular. Usa avalúos reales de 2014–2025; post desde 2019 y referencia anual 2018. Buffers de 400 y 800 m, con 1200 m adicional; gradiente continuo `1/(distancia+1000)`. La nueva área de influencia está excluida del artículo.

Se conservan registros catastrales detallados, efectos fijos de lote y año, errores agrupados por barrio y el peso original de cada registro. La muestra común estimada contiene 25.334.749 registros-año, 787.815 lotes y 952 barrios. No es un panel balanceado de construcciones idénticas. Las cachés lote–año reproducen las ecuaciones con regresores constantes en esas celdas, usando pesos de frecuencia; destinos y estratos utilizan los atributos de cada registro en 2018 mediante lote–construcción–resto. No asignar el destino de una sola construcción a todo el lote.

`A_std` es el índice principal: PC1 orientado de siete distancias a redes, transformadas con `-log(1+d)` y estandarizadas, incluyendo distancias cero. Se construye en `Código/7_centralidades.do`; `I_AccB` y la delimitación AI pertenecen al análisis histórico. Empleo, CBD y equipamientos son moderadores distintos. Las moderaciones principales incluyen `post × M`.

## Narrativa y evidencia

Orden acordado: efecto promedio, destinos y estratos brevemente, heterogeneidad espacial por accesibilidad estructural, otros moderadores y discusión. CEM queda en el anexo D. El Word vigente es `Paper/draft_PLMB_para_Luis_Angel_2026-10-07.docx`; `comparacion_con_LAG_2026-10-07.docx` contiene una comparación real con el original de Luis Ángel, que debe conservarse intacto. La descripción de cambios es `Paper/cambios_realizados_LAG.md` y el encargo de revisión externa es `Paper/prompt_revision_Claude.md`.

Efectos promedio: 3,3–4,2 %. Contraste continuo 400 frente a 800 m: 1,38 % en A=0 y 2,80 % en A=1. La interacción anual aumenta desde 2020. No se afirma que sus coeficientes previos sean todos cero: la prueba conjunta rechaza (p=0,0036). La interpretación causal de complementariedad se apoya en una restricción contrafactual explícita y sensibilidad Rambachan–Roth: intervalo positivo con M=0,5, incluye cero con M=0,75. M limita cambios anuales del contrafactual, no el cociente de niveles de coeficientes. No se identifica el efecto de una política que incremente A.

CEM reutiliza pesos verificados de 2018 para 800 m; no se hace un matching nuevo. ATT ponderado 2,79 %, prueba previa p=0,6476. El nuevo diagnóstico continuo conserva una interacción positiva (p=0,0005), con contraste A=1 de 0,62 % [-0,16;1,42]; su muestra ponderada es distinta y la prueba previa del ATT no valida por extensión la interacción. Pesos concentrados y balance residual se reportan en el anexo.

No se estimará la apertura de frentes de obra ni se aplicará un estimador de adopción escalonada sin tratamiento definido. El stock de área construida del ejercicio histórico tampoco identifica disrupciones de obra. La discusión relaciona el event study promedio con implementación antes de operación: el premium podría crecer al terminar la obra, sin afirmar un límite inferior identificado ni aislar pérdidas causadas por construir. La captura de valor es una relevancia central: hay que considerar estructura urbana y heterogeneidad, sin elegir instrumentos. Hay un placeholder explícito para que Álex amplíe esa discusión.

Álex confirmó que las bases urbanas son anteriores a 2019 y está rastreando los originales. Faltan fuente, fecha y versión por capa; la confirmación verbal no reemplaza documentación de cada insumo.

## Código y reproducción

`Código/paper/README.md` describe los programas 10–27 de Stata. Resultados vigentes: `Paper/stata_results/diagnosticos_2026-10-06/`. El nombre de la carpeta se mantiene aunque el diagnóstico CEM y las figuras se añadieron el 7 de octubre. Modelos, CSV, logs, cachés y marcadores de verificación están guardados. Leerlos antes de proponer cualquier corrida costosa.

`Paper/revision_2026-10-06/construir_texto.py` reconstruye la narrativa y tablas desde CSV; no estima. `27_figuras_paper.do` regenera dos figuras desde CSV; no ajusta modelos. El módulo 24 tiene etapa `resultados` para leer el modelo guardado, pero su etapa predeterminada sí estima. El módulo 26 estima solo el contraste continuo CEM; no relanzar todos los módulos para revisar el paper. El Python histórico no replica por sí solo el bloque actual y conserva rutas de un entorno anterior.

## Preservación y límites

No borrar bases originales/procesadas, `.ster`, CSV finales, pesos, cachés útiles ni marcadores. Los archivos históricos se recuperan de `Paper/archivo/2026-10-06/` y `Paper/archivo/2026-10-07/`, con inventarios y hashes. `document versions` y resultados Python antiguos están archivados; las tres tablas de manzanas en parquet y todos los scripts Python se conservan activos. No volver a introducir las opciones antiguas como especificación actual.

Preservar cambios manuales del usuario. No commit, push, migración ni rerun prolongado sin autorización. La revisión externa debe ser de lectura: comprobar escrito, código y resultados guardados y distinguir errores concretos de sugerencias opcionales.
