import mysql.connector

def obtener_conexion():
    conexion = mysql.connector.connect(
        host="localhost",
        port=3306,
        user="TU_USUARIO",
        password="TU_CONTRASEÑA",
        database="torneo_futbol5"
    )

    return conexion