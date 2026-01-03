###### TEDx-Load-Aggregate-Model
######

import sys
import json
import pyspark
# Import necessari per la pulizia, l'aggregazione e il logging
from pyspark.sql.functions import col, collect_list, regexp_replace, trim, count, when, isnan, isnull

from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job


##### PATH DEI FILE
S3_BASE_PATH = "s3://tedxschool-2025-data/"
tedx_dataset_path = S3_BASE_PATH + "final_list.csv"


###### READ PARAMETERS
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

##### START JOB CONTEXT AND JOB
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

job = Job(glueContext)
job.init(args['JOB_NAME'], args)

print("#### INIZIO PROCESSO ETL TEDX ####")

# =========================================================================
# === FASE 1: LETTURA FINAL_LIST E CREAZIONE MAPPA SLUG -> ID CORRETTO ===

#### READ INPUT FILES TO CREATE AN INPUT DATASET (final_list.csv)
tedx_dataset = spark.read \
.option("header","true") \
.option("quote", "\"") \
.option("escape", "\"") \
.csv(tedx_dataset_path)

print(f"INFO: Letti {tedx_dataset.count()} record da final_list.csv (fonte di verità degli ID)")

# Creiamo la tabella di lookup slug -> id, usata per risolvere gli ID errati in related_videos
slug_id_map_df = tedx_dataset.select(
col("slug").alias("slug_lookup"),
col("id").alias("correct_id")
)

# =========================================================================
# === FASE 2: PULIZIA E JOIN DETTAGLI (details.csv) ===

## Legge detais.csv e pulisce i dati
details_dataset_path = S3_BASE_PATH + "details.csv"
details_dataset = spark.read \
.option("header","true") \
.option("quote", "\"") \
.option("escape", "\"") \
.option("multiLine", "true") \
.csv(details_dataset_path)

# --- LOGGING PRE-PULIZIA ---
details_with_newline = details_dataset.filter(col("description").contains("\n"))
count_newline = details_with_newline.count()

print(f"WARNING: Trovate {count_newline} righe in details.csv che richiedono pulizia (contengono '\\n').")

if count_newline > 0:
  print("LOG: Prime 5 righe PRIMA della pulizia (per verificare lo shift di colonne):")
  details_with_newline.select("id", "description", "duration", "publishedAt").show(5, truncate=False)
# ---------------------------

# Rimuove i caratteri di interruzione di riga e normalizza gli spazi
details_dataset = details_dataset.withColumn(
"description",
regexp_replace(col("description"), "[\\n\\r\\t]", " ")
).withColumn(
"description",
regexp_replace(col("description"), " +", " ")
).withColumn(
"description",
trim(col("description"))
)

# --- LOGGING POST-PULIZIA ---
if count_newline > 0:
  # Filtra il dataset pulito solo sugli ID che erano problematici per la verifica
  ids_to_check = details_with_newline.select("id").rdd.flatMap(lambda x: x).collect()
  details_cleaned_check = details_dataset.filter(col("id").isin(ids_to_check))

print("LOG: Le stesse 5 righe DOPO la pulizia (duration e publishedAt dovrebbero essere popolati):")
details_cleaned_check.select("id", "description", "duration", "publishedAt").show(5, truncate=False)

details_dataset = details_dataset.select(col("id").alias("id_ref"),
col("description"),
col("duration"),
col("publishedAt"))

# AND JOIN WITH THE MAIN TABLE
tedx_dataset_main = tedx_dataset.join(details_dataset, tedx_dataset.id == details_dataset.id_ref, "left") \
.drop("id_ref")

print(f"INFO: Completata la join con details.csv pulito. Totale record: {tedx_dataset_main.count()}")


# =========================================================================
# === FASE 3: AGGREGAZIONE E JOIN TAGS (tags.csv) ===

## Legge TAGS DATASET
tags_dataset_path = S3_BASE_PATH + "tags.csv"
tags_dataset = spark.read.option("header","true").csv(tags_dataset_path)

# Aggiunge TAGS a TEDX_DATASET
tags_dataset_agg = tags_dataset.groupBy(col("id").alias("id_ref")).agg(collect_list("tag").alias("tags"))

# JOIN CON I TAG
tedx_dataset_agg = tedx_dataset_main.join(tags_dataset_agg, tedx_dataset_main.id == tags_dataset_agg.id_ref, "left") \
.drop("id_ref")


# =========================================================================
# === FASE 4: RISOLUZIONE, AGGREGAZIONE E JOIN RELATED VIDEOS (related_videos.csv) ===

## READ RELATED_VIDEOS DATASET
related_videos_dataset_path = S3_BASE_PATH + "related_videos.csv"
related_videos_dataset = spark.read.option("header","true").csv(related_videos_dataset_path)

total_suggestions = related_videos_dataset.count()

# === ANALISI QUALITÀ RELATED_VIDEOS ===
print("\n=== ANALISI QUALITÀ RELATED_VIDEOS ===")

# 1. Crea set di ID e Slug VALIDi
valid_ids = tedx_dataset.select(col("id").alias("valid_id")).distinct()
valid_slugs = tedx_dataset.select(col("slug").alias("valid_slug")).distinct()

# 2. Conta ID validi (specifica related_videos.id vs valid_id)
related_id_validi_count = related_videos_dataset.join(valid_ids,
col("related_id") == col("valid_id"), "inner").count()
related_id_validi_pct = (related_id_validi_count / total_suggestions) * 100

# 3. Conta Slug validi (specifica related_videos.slug vs valid_slug)
slug_validi_count = related_videos_dataset.join(valid_slugs,
col("slug") == col("valid_slug"), "inner").count()
slug_validi_pct = (slug_validi_count / total_suggestions) * 100

print(f"Totale suggerimenti: {total_suggestions:,}")
print(f"related_id validi: {related_id_validi_count:,} ({related_id_validi_pct:.1f}%)")
print(f"Slug validi (main): {slug_validi_count:,} ({slug_validi_pct:.1f}%)")
print("═" * 50)

# 4. DECISIONE AUTOMATICA
USE_SLUG_ONLY = slug_validi_pct > 85
if USE_SLUG_ONLY:
  print("Slug quality OK → Procedo con strategia SLUG ONLY")
else:
  print(" Slug quality bassa → CONSIDERARE fallback ID+Slug")
  print("═" * 50)

# RISOLUZIONE: Joina related_videos con la mappa di lookup (slug_id_map_df) usando lo SLUG.
# L'INNER JOIN garantisce che vengano inclusi solo i video correlati con uno SLUG valido.
resolved_videos_df = related_videos_dataset.join(
  slug_id_map_df,
  related_videos_dataset.slug == slug_id_map_df.slug_lookup,
  "inner"
  ).select(
  # ID del talk principale (che riceve il suggerimento)
  col("id").alias("main_talk_id"),
  # ID CORRETTO del talk suggerito - PRENDIAMO correct_id DALLA MAPPA
  col("correct_id").alias("target_video_id")
  )

valid_suggestions = resolved_videos_df.count()
discarded_suggestions = total_suggestions - valid_suggestions

# --- LOGGING FILTRO ---
print(f"INFO: In related_videos.csv, c'erano {total_suggestions} suggerimenti totali.")
if discarded_suggestions > 0:
  print(f"WARNING: Scartati {discarded_suggestions} suggerimenti (ID o Slug non trovati in final_list.csv) tramite INNER JOIN.")
  print(f"INFO: Mantenuti {valid_suggestions} suggerimenti validi con ID risolto.")
# ----------------------

# AGGREGAZIONE: Raggruppa per 'main_talk_id' e colleziona tutti i 'target_video_id' in un array
related_videos_agg = resolved_videos_df.groupBy("main_talk_id").agg(
collect_list("target_video_id").alias("related_videos")
)

# JOIN: Unisci i video correlati aggregati al DataFrame principale
tedx_dataset_agg = tedx_dataset_agg.join(
related_videos_agg,
tedx_dataset_agg.id == related_videos_agg.main_talk_id,
"left"
) \
.drop("main_talk_id") # Rimuoviamo la colonna duplicata usata per la join



# =========================================================================
# === FASE 5: CREAZIONE CLASSROOMS ===

from pyspark.sql.functions import rand, row_number, col
from pyspark.sql.window import Window

NUM_CLASSI = 10
VIDEOS_PER_CLASSE = 3
total_videos = NUM_CLASSI * VIDEOS_PER_CLASSE

# randomizzazione
tedx_ids = tedx_dataset_agg.select(col("_id").alias("idtedx"))
random_ids_df = tedx_ids.orderBy(rand()).limit(total_videos)

# ID incrementale
window_spec = Window.orderBy("idtedx")  # Ordina per ID casuale già fatto
classrooms_df = random_ids_df.withColumn("id_classroom", row_number().over(window_spec))

classrooms_final = classrooms_df.select("id_classroom", col("idtedx").alias("assigned_tedx"))


# =========================================================================
# === FASE 6: SCRITTURA DOPPIA SU MONGODB ===

write_mongo_options = {
    "connectionName": "Mongodbatlas connection TEDxSchool",
    "database": "unibg_tedx_2025",
    "ssl": "true",
    "ssl.domain_match": "false"
}

# SCRIVI TEDX_DATA
tedx_dynamic_frame = DynamicFrame.fromDF(tedx_dataset_final, glueContext, "tedx_final")
glueContext.write_dynamic_frame.from_options(
    tedx_dynamic_frame, 
    connection_type="mongodb", 
    connection_options={**write_mongo_options, "collection": "tedx_data"}
)

# SCRIVI CLASSROOMS
classrooms_dynamic_frame = DynamicFrame.fromDF(classrooms_final, glueContext, "classrooms")
glueContext.write_dynamic_frame.from_options(
    classrooms_dynamic_frame, 
    connection_type="mongodb", 
    connection_options={**write_mongo_options, "collection": "classrooms"}
)

from awsglue.dynamicframe import DynamicFrame
classrooms_dynamic_frame = DynamicFrame.fromDF(classrooms_final, glueContext, "classrooms")
glueContext.write_dynamic_frame.from_options(classrooms_dynamic_frame, connection_type="mongodb", connection_options=write_classrooms_options)

print("Scrittura su MongoDB eseguita")

print("#### FINE PROCESSO ETL TEDX - Dati scritti su MongoDB Atlas ####")
job.commit()
