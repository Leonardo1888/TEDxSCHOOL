import json
from pymongo import MongoClient

MONGO_URI = "mongodb+srv://unibg2025:unibg2025@mycluster.mpofoqq.mongodb.net/"
client = MongoClient(MONGO_URI)
db = client.unibg_tedx_2025
collection = db.classrooms

def genera_classe_italiana():
    collection.delete_many({"name": "3A Liceo Classico"}) # Pulizia test
    
    classe_test = {
        "name": "3A Liceo Classico",
        "students": ["mario@studenti.it", "giulia@studenti.it"],
        "assignments": [
            {
                "prof_email": "rossi.matematica@scuola.it",
                "subject": "matematica",
                "video_id": "118934",
                "date": "2026-01-06"
            },
            {
                "prof_email": "bianchi.storia@scuola.it",
                "subject": "storia",
                "video_id": "130144",
                "date": "2026-01-05"
            }
        ]
    }
    collection.insert_one(classe_test)
    print("Classe creata con successo!")

genera_classe_italiana()