# TIF_PLMB

# Análisis de Factibilidad TIF para la PLMB
## Modelación Econométrica y Geoespacial en Stata

**Autora:** Maria Corina Hernandez
**E-mail:** mc.hernandezl12@uniandes.edu.co
**Consultoría original:** Febrero–Marzo 2026

---

## Descripción histórica de la consultoría

La consultoría original, cuya descripción se conserva aquí como antecedente, contiene el código fuente para estimar el mayor valor del avalúo catastral en el área de influencia de la Primera Línea del Metro de Bogotá (PLMB). El objetivo central es evaluar la viabilidad del instrumento **Tax Increment Financing (TIF)** para financiar la extensión de la línea, utilizando un panel de datos catastrales de la UAECD (2014–2025).

La estrategia de identificación es un modelo de **Diferencias en Diferencias (DiD)** que compara la evolución de los avalúos catastrales entre predios dentro y fuera del área de influencia del metro, antes y después del anuncio/contratación del proyecto (2019).

## Paper

El código del artículo está en [`Código/paper`](Código/paper/README.md) y se corre con `00_master.do`. Los resultados quedan en `Paper/resultados` de la carpeta de OneDrive `RA Andes - TIF`. Las exportaciones `README.pdf`, `README.html` y `README.tex` son de la consultoría.

---

## Estructura del repositorio y pipeline histórico

```
TIF_PLMB/
├── Código/                          → Do-files de Stata (ver sección siguiente)
├── Datos/
│   ├── raw/
│   │   ├── INFORMACIÓN CATASTRAL Y PREDIAL/   → PREDIO_FINAL_20YY.csv (2014–2025)
│   │   ├── SHAPES/                            → Shapefiles y DBFs de ArcGIS
│   │   │   ├── Lotes_catastrales.gdb.zip.gdrive/
│   │   │   ├── Lotes_catastrales_treatment/   → Buffers 400/800/1200m
│   │   │   ├── Lotes_catastrales_treat_robust/
│   │   │   ├── manzanas_contrafac.csv
│   │   │   ├── manzanas_linea_interv.csv
│   │   │   └── manzanas_AI_vias_tramos.csv
│   │   ├── EM2021_800m_PLMB/                  → Datos de empleo 2021
│   │   └── Nueva Área de Influencia/          → BASE_NUEVA_AI_20YY.csv (2014–2025)
│   ├── processed/                   → Archivos .dta generados por los do-files
│   └── outcomes/                    → Tablas (.docx) y gráficos (.pdf) finales
├── inflacion.xlsx                   → IPC mensual 2014–2025 (DANE)
├── README.md
```

---

## Estructura del Código (.do files)

El flujo de trabajo se divide en nueve etapas principales:

### Etapa 1 — Preparación de Datos

**`1_append_merge.do`**
Limpieza y estandarización de las 12 bases catastrales anuales de la UAECD. Crea un panel balanceado (solo predios observados los 12 años) y lo vincula con la información geográfica de tratamiento proveniente de ArcGIS.

- **Entrada:** `PREDIO_FINAL_20YY.csv` (2014–2025), `Lotes_catastrales.dbf`
- **Salida:** `predios_completos.dta`, `predios_balanceado.dta`, `predios_tratamiento_shp.dta`, `predios.dta`

### Etapa 2 — Modelo DiD Principal

**`2_analysis_did.do`**
Implementación del modelo de Diferencias en Diferencias. Deflacta los avalúos a precios constantes de 2014 usando el IPC de diciembre de cada año, genera el logaritmo natural de los valores reales, y estima el efecto promedio del tratamiento (ATT) con efectos fijos de lote y año. Incluye un event study (ventanas dinámicas 2014–2025) para verificar tendencias paralelas.

- **Entrada:** `predios.dta`, `inflacion.xlsx`
- **Salida:** `predios_proc.dta`, `DID_simple.docx` (parcial), `DiD_windows_1200.pdf`, `DiD_windows_com_1200.pdf`, `DiD_windows_filter.pdf`

### Etapa 3a — Atributos Físicos

**`3_analysis_did_atributes.do`**
Analiza si el tratamiento está asociado a cambios en atributos físicos de los predios (área construida, número de pisos), tanto a nivel de predio como de manzana. Incluye un diseño de discontinuidad espacial con el Área de Influencia de Manzanas (AIM).

- **Entrada:** `predios_proc.dta`, `manzanas_linea_interv.csv`, `manzanas_uso_suelo.dta`, `manzanas_treat_aim.csv`, `manzanas_untreat_aim_donut.csv`
- **Salida:** `manzanas_proc.dta`, `DID_atributes.docx`, `DID_atributes_aim.docx`, `DiD_windows_area.pdf`

### Etapa 3b — Efectos Heterogéneos (Destino, Estrato, Tramo)

**`3_analysis_did_heter.do`**
Estima efectos heterogéneos del tratamiento según destino económico del predio (residencial, comercial, industrial, dotacional, etc.), estrato socioeconómico y tramo de la línea. Los destinos y estratos se fijan al periodo pre-tratamiento para evitar endogeneidad por cambio de uso.

- **Entrada:** `predios_proc.dta`
- **Salida:** `DID_heter_dest.docx`, `DID_heter_estr.docx`, `DID_heter_dest_res.docx`, `DID_heter_tram.docx`, `DiD_windows_tram.pdf`

### Etapa 4 — Coarsened Exact Matching (CEM)

**`4_analysis_cem.do`**
Aplica CEM para mejorar la comparabilidad entre grupos de tratamiento y control, usando como covariables de matching: estrato, área construida, número de pisos, destino económico y distancias al CBD, Transmilenio, malla vial y trazado PLMB (todas en quintiles). El matching se realiza sobre el corte transversal de 2018 (último año pre-tratamiento). Los pesos se fusionan al panel completo para la estimación DiD ponderada.

- **Entrada:** `predios_proc.dta`, `Distancias_Manzanas-CBD.csv`, `Distancias_Manzanas-TrazadoPLMB.csv`, `Distancias_Manzanas-TM.csv`, `Distancias_Manzanas-MallaVialArterial.csv`
- **Salida:** `treat_CEM.dta`, `treat_weights.dta`, `DID_CEM.docx`

### Etapa 5 — Análisis Exploratorio: Distintos Buffers

**`5_robustez.do`**
Corre el modelo DiD para buffers de 400m y 1200m usando una segunda definición de shapefiles de tratamiento (`Lotes_catastrales_treat_robust`). Este ejercicio fue realizado para explorar sensibilidad a distintos radios por solicitud del equipo; no constituye la especificación base.

- **Entrada:** `predios_proc.dta`, `Lotes_catastrales_treat_robust.dbf`
- **Salida:** `predios_robust.dta`, `DID_simple.docx` (con columnas 400m y 1200m)

### Etapa 6 — Nueva Área de Influencia (especificación histórica)

**`6_nueva_ai.do`**
Replica el pipeline completo (preparación, deflactación, DiD base, heterogeneidad por destino, estrato y tramo) usando la **nueva área de influencia** como grupo de tratamiento. A diferencia de un buffer de radio fijo, esta área está delimitada por avenidas y vías importantes cercanas al corredor del metro. Fue sugerida por entidades gubernamentales para dar soporte legal a la delimitación: respeta la geometría urbana (no corta manzanas a la mitad) y es la **definición por defecto para todos los análisis que siguen a este archivo**.

El grupo de control es el conjunto de predios del universo catastral de Bogotá fuera del área de influencia (ciudad completa menos el grupo de tratamiento).

- **Entrada:** `BASE_NUEVA_AI_20YY.csv` (2014–2025), `predios_completos.dta`, `Lotes_catastrales.dbf`, `inflacion.xlsx`, `manzanas_AI_vias_tramos.csv`
- **Salida:** `predios_proc_ai2.dta`, `DID_heter_dest.docx` (col. "AI Vías"), `DID_heter_estr.docx` (col. "AI Vías"), `DID_heter_tram.docx` (col. "AI Vías")

### Etapa 7 — Índices de Accesibilidad Urbana

**`7_centralidades.do`**
Construye índices de accesibilidad urbana a nivel de manzana usando una base de datos de Bogotá (`base_bogota_270221.dta`). Genera tres tipos de índices:

- **Accesibilidad de transporte:** promedio simple, tipo gravedad (γ=0.5) y decaimiento exponencial (λ=0.01) de distancias inversas a vías troncales, locales e intermedias.
- **Acceso económico:** log(empleo) × índice de transporte.
- **Equipamientos (amenidades):** índice de distancias inversas a equipamientos de educación, salud, recreación, etc.
- **Índice compuesto I_AccB:** análisis de componentes principales (PCA) sobre 17 variables de distancia/accesibilidad, con ponderación por eigenvalor; produce 4 dimensiones (accesibilidad estructural, periferia-ruralidad, capilaridad urbana, corredores específicos).

Los índices se pegan a `predios_proc_ai2.dta` para su uso en análisis de heterogeneidad.

- **Entrada:** `predios_proc_ai2.dta`, `Distancias_Manzanas-*.csv`, `base_bogota_270221.dta`
- **Salida:** `manzanas_access.dta`, estimaciones de heterogeneidad con accesibilidad continua

### Etapa 8 — Robustez: Grupo de Control Alternativo

**`8_robustez_control.do`**
Prueba de sensibilidad a la definición del grupo de control. En lugar de usar toda la ciudad como control (especificación base), este archivo define un contrafactual espacialmente acotado: las manzanas dentro de un **buffer de 1500m alrededor de la nueva área de influencia** pero por fuera del área de tratamiento. Esto reduce la posibilidad de que el grupo de control capture dinámicas urbanas muy distintas al corredor del metro, a costa de reducir el tamaño del grupo de control.

- **Entrada:** `predios_proc_ai2.dta`, `manzanas_contrafac.csv` (manzanas en el anillo 1500m alrededor de la nueva AI), `manzanas_AI_vias_tramos.csv`
- **Salida:** Estimaciones DiD con control restringido al anillo perimetral (heterogeneidad por destino, estrato y tramo)

### Etapa 9 — Heterogeneidad por Destino/Estrato × Accesibilidad

**`9_heter_access.do`**
Estima efectos heterogéneos de tercer orden: `treat × destino económico × accesibilidad` y `treat × estrato × accesibilidad`. Responde si el efecto diferencial del metro sobre cada tipo de predio varía según el nivel de accesibilidad urbana preexistente de la manzana. Relevante para TIF: identifica si la base imponible capturable se concentra en zonas de alta o baja accesibilidad.

- **Entrada:** `predios_proc_ai2.dta`, `manzanas_access.dta`
- **Salida:** `DID_heter_dest_access.docx`, `DID_heter_estr_access.docx`, `DiD_heter_dest_access.pdf`

---

## Metodología histórica de la consultoría

### Especificación Principal

```stata
reghdfe ln_avaluo_real_2014 treat, a(codigo_lote year) vce(cluster codigo_barrio)
```

Donde:
- **Variable dependiente:** `ln_avaluo_real_2014` — logaritmo del avalúo catastral en pesos constantes de 2014
- **Variable de tratamiento:** `treat = 1` si el predio está dentro del área de influencia **y** el año es ≥ 2019. La variable concreta a usar (`treatment_800`, `treatment_1200` o la variable de la nueva AI) depende del objetivo del análisis; la definición **base es 800m** (`treatment_800`).
- **Efectos fijos:** lote (`codigo_lote`) + año (`year`)
- **Errores estándar:** clusterizados a nivel de barrio (`codigo_barrio`)
- **Grupo de control:** el universo de predios de Bogotá fuera del área de influencia definida (ciudad completa menos el grupo de tratamiento), excepto en `8_robustez_control.do` donde se usa un contrafactual espacialmente definido (ver Etapa 8).

### DiD Dinámico (Tendencias Paralelas)

Para verificar el supuesto de tendencias paralelas y visualizar la dinámica temporal del efecto, se estima un **DiD dinámico** (o DiD con ventanas de tiempo): se interactúa el indicador de tratamiento con dummies de año calendario, omitiendo 2018 como año de referencia.

> **Nota terminológica:** Los gráficos de coeficientes resultantes (archivos `DiD_windows_*.pdf`) suelen denominarse coloquialmente "event study plots" en la literatura, pero técnicamente son **coeficientes de un DiD dinámico indexados por año calendario** (2014, 2015, ..., 2025), no por tiempo relativo al tratamiento (t−5, t−4, ...). Dado que el tratamiento es simultáneo para todas las unidades (2019), ambas representaciones son matemáticamente equivalentes y los coeficientes son idénticos; solo diferiría el etiquetado del eje x. En un diseño con adopción escalonada (*staggered*), la distinción sería sustantiva.

```stata
forvalues i = 2014/2025 {
    gen trat_`i' = cond(year==`i', 1*treatment_800, 0)
}
replace trat_2018 = 0   // año omitido (referencia)

reghdfe ln_avaluo_real_2014 trat_*, a(codigo_lote year) vce(cluster codigo_barrio)
coefplot ..., keep(trat_*) vertical yline(0)
```

### Deflactación

Los valores nominales se convierten a precios constantes de 2014 usando el IPC de diciembre de cada año (DANE):

```
cum_mult_2014 = 1
cum_mult_t    = cum_mult_{t-1} × (1 + IPC_t / 100)   para t > 2014
avaluo_real_2014 = valor_avaluo_nominal / cum_mult_t
```

### Exclusiones

Se excluyen de todas las estimaciones los predios con los siguientes destinos económicos (no capturable por TIF):
- VIAS, ESPACIO PÚBLICO, LOTE DEL ESTADO, DOTACIONAL PÚBLICO, RECREACIONAL PÚBLICO

### Áreas de Influencia

| Definición | Variable | Uso |
|------------|----------|-----|
| 400m | `treatment_400` | Exploratoria (buffer estrecho) |
| **800m** | **`treatment_800`** | **Especificación base** |
| 1200m | `treatment_1200` | Ejercicio exploratorio (solicitado; no es la especificación principal) |
| Nueva AI | `treatment` (archivo 6) | **Uso histórico en archivos 6–9; excluida del paper actual** |

> **Nueva Área de Influencia:** Parte aproximadamente del rango de 800–1200 m y ajusta el borde a manzanas y corredores principales, como la NQS y la Autopista. Esta definición fue sugerida por entidades gubernamentales para delimitar el perímetro de influencia. El ajuste evita cortar manzanas, pero depende de decisiones sobre la estructura urbana que pueden estar relacionadas con las tendencias previas del avalúo; por eso se contrasta con los buffers de radio fijo.

---

## Datos Procesados Intermedios

| Archivo | Descripción | Generado en |
|---------|-------------|------------|
| `predios_completos.dta` | Panel completo sin balancear | `1_append_merge.do` |
| `predios_balanceado.dta` | Solo predios observados los 12 años | `1_append_merge.do` |
| `predios_tratamiento_shp.dta` | Variables de tratamiento y tramo del shapefile | `1_append_merge.do` |
| `predios.dta` | Panel balanceado + tratamiento | `1_append_merge.do` |
| `predios_proc.dta` | Panel + valores reales deflactados (~5.4 GB) | `2_analysis_did.do` |
| `predios_robust.dta` | Panel + tres definiciones de buffer (~5.5 GB) | `5_robustez.do` |
| `manzanas_proc.dta` | Panel colapsado a nivel manzana + tratamiento | `3_analysis_did_atributes.do` |
| `treat_CEM.dta` | Muestra de 2018 con pesos CEM | `4_analysis_cem.do` |
| `treat_weights.dta` | Pesos CEM para merge al panel | `4_analysis_cem.do` |
| `predios_proc_ai2.dta` | Pipeline completo sobre nueva AI | `6_nueva_ai.do` |
| `manzanas_access.dta` | Índices de accesibilidad a nivel manzana | `7_centralidades.do` |

---

## Descripción de Outcomes

### Tablas de Regresión (formato .docx, generadas con `outreg2`)

| Archivo | Contenido |
|---------|-----------|
| `DID_simple.docx` | ATT sobre avalúo catastral real — buffers 400m, 800m, 1200m |
| `DID_heter_dest.docx` | Heterogeneidad por destino económico (AI 1200m y AI Vías) |
| `DID_heter_estr.docx` | Heterogeneidad por estrato socioeconómico (residencial) |
| `DID_heter_dest_res.docx` | ATT solo sobre predios residenciales |
| `DID_heter_tram.docx` | Heterogeneidad por tramo de la PLMB |
| `DID_CEM.docx` | ATT con muestra emparejada por CEM |
| `DID_atributes.docx` | Efecto sobre área construida (nivel manzana) |
| `DID_atributes_aim.docx` | Efecto sobre área construida — diseño AIM |
| `DID_heter_dest_access.docx` | Heterogeneidad destino × accesibilidad |
| `DID_heter_estr_access.docx` | Heterogeneidad estrato × accesibilidad (residencial) |

### Gráficos de Coeficientes (formato .pdf)

| Archivo | Contenido |
|---------|-----------|
| `DiD_windows_1200.pdf` | Event study — avalúo catastral, buffer 1200m |
| `DiD_windows_com_1200.pdf` | Event study — valor comercial, buffer 1200m |
| `DiD_windows_filter.pdf` | Event study — sin predios públicos |
| `DiD_windows_area.pdf` | Event study — área construida nivel manzana |
| `DiD_windows_tram.pdf` | Event study — por tramo (Tramo 1, 2, 3) |
| `DiD_heter_dest_access.pdf` | ATT por destino económico dentro de cada quintil de accesibilidad |

---

## Requerimientos

Instalar los siguientes paquetes en Stata antes de ejecutar:

```stata
ssc install reghdfe
ssc install ftools
ssc install outreg2
ssc install cem
ssc install coefplot
```

---

## Configuración de Rutas

Cada do-file define al inicio:

```stata
global dir_0 "C:\Users\USUARIO\\"
```

Los datos se esperan en:
```
${dir_0}OneDrive - Universidad de los andes\RA Andes - TIF\Datos\
```

Los outcomes se exportan a:
```
${dir_0}Documents\GitHub\TIF_PLMB\Datos\outcomes\
```

> **Nota:** Asegurarse de que solo una línea `global dir_0` esté activa en cada archivo (la segunda línea debe estar comentada con `//`).

---

## Orden de Ejecución

Los do-files deben correrse en este orden. Los archivos 3a y 3b pueden ejecutarse en paralelo después del 2.

```
1_append_merge.do
    └── 2_analysis_did.do
            ├── 3_analysis_did_atributes.do
            ├── 3_analysis_did_heter.do
            ├── 4_analysis_cem.do
            └── 5_robustez.do
                    └── paper/13_pretrends_buffers.do
6_nueva_ai.do
    └── 7_centralidades.do
            ├── 9_heter_access.do  (análisis de la consultoría con I_AccB)
            └── paper/10_paper.do
                    └── paper/12_comparar_postM.do
paper/11_paper_ofertas.do  (comparación transversal con ofertas)
8_robustez_control.do   (requiere predios_proc_ai2.dta de 6_nueva_ai.do)
```
