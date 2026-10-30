import bcrypt

clave = "ContraseñaMuySeguraAdmin777"
hash_ = bcrypt.hashpw(clave.encode("utf-8"), bcrypt.gensalt(12)).decode("utf-8")
print(hash_)

clave2 = "ContraseñaPlanillero456"
hash_ = bcrypt.hashpw(clave2.encode("utf-8"), bcrypt.gensalt(12)).decode("utf-8")
print(hash_)