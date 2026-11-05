from database import obtener_conexion

try:
    conexion = obtener_conexion()

    if conexion.is_connected():
        print("¡Conexión exitosa con MySQL!")

    conexion.close()

except Exception as error:
    print("Error al conectar con MySQL:")
    print(error)