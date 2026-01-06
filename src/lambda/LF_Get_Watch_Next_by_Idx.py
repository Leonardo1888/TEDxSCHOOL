import json
import os
from pymongo import MongoClient

MONGO_URI = "mongodb+srv://unibg2025:unibg2025@mycluster.mpofoqq.mongodb.net/"
client = MongoClient(MONGO_URI)
db = client.unibg_tedx_2025
collection = db.tedx_clean_data_2

def lambda_handler(event, context):
    try:
        # Recupero ID dall'URL (es: /watchnext?id=100858)
        talk_id = event.get('queryStringParameters', {}).get('id')
        
        if not talk_id:
            return {"statusCode": 400, "body": json.dumps("ID mancante")}

        # Recupero il talk principale
        current_talk = collection.find_one({"_id": talk_id})
        if not current_talk:
            return {"statusCode": 404, "body": json.dumps("Talk non trovato")}

        related_list = current_talk.get('related_videos_data', [])
        
        # Recuperiamo i voti aggiornati e le materie dei correlati
        related_ids = [v['id'] for v in related_list]
        full_related_docs = list(collection.find({"_id": {"$in": related_ids}}))

        # IL MODELLO DI ANALISI
        current_subjects = set(current_talk.get('subjects', []))
        current_tags = set(current_talk.get('tags', []))
        
        results = []
        for doc in full_related_docs:
            doc_subjects = set(doc.get('subjects', []))
            doc_tags = set(doc.get('tags', []))
            
            # Calcolo Score
            # Punteggio 1: Materie in comune
            subject_score = len(current_subjects.intersection(doc_subjects))
            # Punteggio 2: Voto dei Professori (avg_rating creato dal job Glue)
            rating_score = doc.get('avg_rating', 0)
            # Punteggio 3: Tag in comune
            tag_score = len(current_tags.intersection(doc_tags))
            
            results.append({
                "id": doc["_id"],
                "title": doc.get("title"),
                "speaker": doc.get("main_speaker"),
                "image": doc.get("main_image_url"),
                "subjects": list(doc_subjects),
                "rating": rating_score,
                "scores": {
                    "subject_match": subject_score,
                    "tag_match": tag_score
                },
                "reason": f"Scelto perché affine a {list(current_subjects.intersection(doc_subjects))[0]}" if subject_score > 0 else "Consigliato dalla community"
            })

        # Ordiniamo per: Materie (Primario), Voto Prof (Secondario), Tag (Terziario)
        results.sort(key=lambda x: (x['scores']['subject_match'], x['rating'], x['scores']['tag_match']), reverse=True)

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
            "body": json.dumps(results[:6]) # Restituiamo i top 6
        }

    except Exception as e:
        print(e)
        return {"statusCode": 500, "body": json.dumps("Errore interno")}