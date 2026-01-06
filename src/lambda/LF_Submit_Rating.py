import json
from pymongo import MongoClient

MONGO_URI = "mongodb+srv://unibg2025:unibg2025@mycluster.mpofoqq.mongodb.net/"
client = MongoClient(MONGO_URI)
db = client.unibg_tedx_2025
collection = db.tedx_clean_data_2

def lambda_handler(event, context):
    try:
        # Parsing dei dati in ingresso (ID del video e Voto)
        body = json.loads(event.get('body', '{}'))
        talk_id = body.get('id')
        nuovo_voto = body.get('rating') # Un numero da 1 a 10

        if not talk_id or nuovo_voto is None:
            return {"statusCode": 400, "body": json.dumps("Dati mancanti (id o rating)")}

        if nuovo_voto < 1 or nuovo_voto > 10:
            return {"statusCode": 400, "body": json.dumps("Il voto deve essere compreso tra 1 e 10")}

        # Recupero dati attuali
        talk = collection.find_one({"_id": talk_id})
        if not talk:
            return {"statusCode": 404, "body": json.dumps("Talk non trovato")}

        avg_vecchia = talk.get('avg_rating', 0)
        voti_vecchi = talk.get('num_votes', 0)

        # Calcolo della Nuova Media
        nuovi_voti_totali = voti_vecchi + 1
        nuova_avg = ((avg_vecchia * voti_vecchi) + nuovo_voto) / nuovi_voti_totali
        nuova_avg = round(nuova_avg, 1) # Arrotondiamo a una cifra decimale

        # Aggiornamento su MongoDB
        collection.update_one(
            {"_id": talk_id},
            {"$set": {"avg_rating": nuova_avg, "num_votes": nuovi_voti_totali}}
        )

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
            "body": json.dumps({
                "message": "Voto registrato con successo",
                "vecchia_avg": avg_vecchia,
                "new_avg": nuova_avg,
                "total_votes": nuovi_voti_totali
            })
        }

    except Exception as e:
        return {"statusCode": 500, "body": json.dumps(str(e))}