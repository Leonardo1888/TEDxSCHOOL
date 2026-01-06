import json
from pymongo import MongoClient

MONGO_URI = "mongodb+srv://unibg2025:unibg2025@mycluster.mpofoqq.mongodb.net/"
client = MongoClient(MONGO_URI)
db = client.unibg_tedx_2025
collection = db.classrooms

def lambda_handler(event, context):
    try:
        # Recupero dati dal body della richiesta (da Flutter)
        body = json.loads(event.get('body', '{}'))
        class_name = body.get('class_name') # "3A Liceo Classico"
        prof_email = body.get('prof_email')
        subject = body.get('subject')
        video_id = body.get('video_id')
        date = body.get('date', "2026-01-06") # Default se manca

        if not all([class_name, video_id, prof_email]):
            return {"statusCode": 400, "body": json.dumps("Dati mancanti")}

        # Aggiornamento su MongoDB tramite $push
        result = collection.update_one(
            {"name": class_name},
            {
                "$push": {
                    "assignments": {
                        "prof_email": prof_email,
                        "subject": subject,
                        "video_id": video_id,
                        "date": date
                    }
                }
            }
        )

        if result.matched_count == 0:
            return {"statusCode": 404, "body": json.dumps("Classe non trovata")}

        return {
            "statusCode": 200,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps("Compito assegnato con successo!")
        }

    except Exception as e:
        return {"statusCode": 500, "body": json.dumps(str(e))}