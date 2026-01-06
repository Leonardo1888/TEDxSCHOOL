# 2° Progetto TEDxSchool:
# Primo JOB che pulisce i dati implementando la funzionalità subject (in base ai tag assegna delle materie ai video).

import sys
import json
from pyspark.sql.functions import col, collect_list, regexp_replace, trim, array, array_contains, lit, array_union, size, struct, array_distinct, when
from pyspark.sql.types import StringType, ArrayType

from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

S3_BASE_PATH = "s3://tedxschool-2025-data/"

# 1. Caricamento Dataset principali
tedx_dataset = spark.read.option("header","true").option("quote", "\"").option("escape", "\"").csv(S3_BASE_PATH + "final_list.csv")
details_dataset = spark.read.option("header","true").option("quote", "\"").option("escape", "\"").option("multiLine", "true").csv(S3_BASE_PATH + "details.csv")
images_df = spark.read.option("header","true").csv(S3_BASE_PATH + "images.csv")

# 2. Pulizia Descrizioni e Join con Immagini (per il video principale)
details_cleaned = details_dataset.withColumn(
    "description", 
    regexp_replace(col("description"), "[\\n\\r\\t]", " ")
).withColumn("description", trim(regexp_replace(col("description"), " +", " ")))

# Uniamo tutto nel main: dati base + dettagli + immagine principale
tedx_main = tedx_dataset \
    .join(details_cleaned.select(col("id").alias("id_det"), "description", "duration", "publishedAt"), tedx_dataset.id == col("id_det"), "left").drop("id_det") \
    .join(images_df.select(col("id").alias("id_img"), col("url").alias("main_image_url")), tedx_dataset.id == col("id_img"), "left").drop("id_img")

# TAGS e SUBJECTS_MAP
tags_df = spark.read.option("header","true").csv(S3_BASE_PATH + "tags.csv")

subjects_map = {
    "scienze": ["biology", "evolution", "genetics", "bacteria", "plants", "animals", "insects", "nature", "microbiology", "marine biology", "botany", "microbes", "birds", "fish", "primates", "dinosaurs", "paleontology", "fungi", "bees", "coral reefs", "biosphere", "deextinction", "synthetic biology", "dna", "crispr", "biotech", "biomimicry", "human body", "physics", "astronomy", "space", "universe", "planets", "solar system", "nasa", "mars", "moon", "sun", "asteroid", "telescopes", "rocket science", "quantum", "string theory", "big bang", "dark matter", "astrobiology", "chemistry", "science", "natural resources", "biodiversity", "exploration", "discovery", "virus", "natural disaster", "curiosity"],
    "storia": ["history", "ancient world", "archaeology", "egypt", "black history", "slavery", "war", "holocaust", "anthropology", "black history month"],
    "filosofia": ["philosophy", "ethics", "religion", "buddhism", "judaism", "islam", "christianity", "hinduism", "atheism", "spirituality", "morality", "consciousness", "humanity", "self", "identity", "ideas", "life", "death", "existence"],
    "letteratura": ["literature", "poetry", "writing", "storytelling", "books", "spoken word", "language", "grammar"],
    "tecnologia": ["technology", "tech", "ai", "artificial intelligence", "machine learning", "algorithms", "software", "code", "computers", "internet", "cyber security", "online privacy", "encryption", "blockchain", "cryptocurrency", "nfts", "metaverse", "virtual reality", "augmented reality", "robots", "drones", "3d printing", "nanotechnology", "ux design", "product design", "innovation", "invention", "engineering", "driverless cars", "bionics", "gadgets", "digitale", "demo", "gaming"],
    "matematica": ["math", "statistics", "data", "visualizations", "geometry", "probability", "logic"],
    "economia": ["economics", "finance", "money", "investing", "business", "marketing", "entrepreneur", "capitalism", "consumerism", "behavioral economics", "accounting", "shopping", "work", "manufacturing", "infrastructure", "women in business", "philanthropy"],
    "arte": ["art", "painting", "photography", "film", "animation", "design", "graphic design", "typography", "industrial design", "architecture", "street art", "visual art", "beauty", "museums", "creativity"],
    "musica": ["music", "performance", "conducting", "sound", "instruments"],
    "educazione civica": ["social change", "activism", "human rights", "equality", "diversity", "inclusion", "feminism", "gender", "transgender", "lgbtqia+", "justice system", "prison", "crime", "corruption", "poverty", "homelessness", "sustainability", "climate change", "environment", "pollution", "renewable energy", "solar energy", "wind energy", "fossil fuels", "policy", "government", "politics", "media", "journalism", "democracy", "public space", "protest", "law", "violence", "sexual violence", "bullying", "race", "vulnerability", "community", "society", "legal"],
    "educazione fisica": ["sports", "exercise", "athletics", "soccer", "competition"],
    "geografia": ["geography", "geology", "maps", "cities", "glaciers", "rivers", "ocean", "weather", "antarctica", "africa", "asia", "europe", "china", "india", "brazil", "united states", "south america", "mountains"],
    "medicina": ["health", "medicine", "public health", "medical imaging", "health care", "vaccines", "disease", "coronavirus", "pandemic", "ebola", "aids", "cancer", "alzheimer's", "diabetes", "heart health", "mental health", "depression", "ptsd", "autism spectrum disorder", "addiction", "therapy", "sleep", "nutrition", "food", "well-being", "mindfulness", "meditation", "happiness", "emotions", "love", "relationships", "parenting", "family", "pregnancy", "hearing", "smell", "sight", "pain", "medical research", "surgery", "brain", "neurology", "neuroscience", "cognitive science", "memory", "body language", "menopause", "ageing", "aging", "women health", "reproductive health", "ted health podcast"],
    "geopolitica": ["middle east", "geopolitics", "international relations", "global issues", "terrorism", "refugees", "immigration", "borders", "military"]
}

# LOG TAG non usati per la console
all_mapped_tags = set([tag for tags in subjects_map.values() for tag in tags])
distinct_tags_in_data = [row['tag'] for row in tags_df.select("tag").distinct().collect()]
not_used_tags = [t for t in distinct_tags_in_data if t not in all_mapped_tags]
print(f"LOG: Totale tag non mappati: {len(not_used_tags)}")

# Aggregazione Tag e Materie
tags_agg = tags_df.groupBy("id").agg(collect_list("tag").alias("tags"))
tedx_with_tags = tedx_main.join(tags_agg, "id", "left")

tedx_with_subjects = tedx_with_tags.withColumn("subjects", array().cast("array<string>"))
for subject, tags in subjects_map.items():
    for t in tags:
        tedx_with_subjects = tedx_with_subjects.withColumn("subjects", 
            when(array_contains(col("tags"), t), array_union(col("subjects"), array(lit(subject)))).otherwise(col("subjects")))

tedx_with_subjects = tedx_with_subjects.withColumn("subjects", array_distinct(col("subjects")))
tedx_with_subjects = tedx_with_subjects.withColumn("subjects", 
    when(size(col("subjects")) == 0, array(lit("Interdisciplinare"))).otherwise(col("subjects")))

# Creiamo la mappa completa con anche l'URL dell'immagine per ogni video
video_info_map = tedx_dataset.join(images_df.select(col("id").alias("id_img"), col("url").alias("image_url")), tedx_dataset.id == col("id_img"), "left") \
    .select(
        col("slug").alias("ref_slug"),
        struct(
            col("id").alias("id"),
            col("title").alias("title"),
            col("slug").alias("slug"),
            col("url").alias("url"),
            col("speakers").alias("speaker"),
            col("image_url").alias("image_url")
        ).alias("video_details")
    )

related_raw = spark.read.option("header","true").csv(S3_BASE_PATH + "related_videos.csv")
related_complete = related_raw.join(video_info_map, related_raw.slug == video_info_map.ref_slug, "inner")
related_agg = related_complete.groupBy("id").agg(collect_list("video_details").alias("related_videos_data"))

# Join Finale
final_df = tedx_with_subjects.join(related_agg, "id", "left").withColumnRenamed("id", "_id")

# SCRITTURA MONGODB
write_mongo_options = {"connectionName": "Mongodbatlas connection", "database": "unibg_tedx_2025", "collection": "tedx_clean_data", "ssl": "true", "ssl.domain_match": "false"}
dynamic_frame = DynamicFrame.fromDF(final_df, glueContext, "final_df")
glueContext.write_dynamic_frame.from_options(dynamic_frame, connection_type="mongodb", connection_options=write_mongo_options)

job.commit()