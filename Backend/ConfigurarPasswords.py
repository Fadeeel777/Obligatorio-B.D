
import bcrypt
from getpass import getpass
from database import obtener_conexion

usuarios = [
    "admin@ucu.edu.uy",
    "planillero@ucu.edu.uy"
]

conexion = None
cursor = None

try:
    conexion = obtener_conexion()
    cursor = conexion.cursor()

    for correo in usuarios:
        password = getpass(f"Contraseña nueva para {correo}: ")

        if len(password) < 8:
            print("La contraseña debe tener al menos 8 caracteres.")
            raise ValueError("Contraseña demasiado corta")

        password_hash = bcrypt.hashpw(
            password.encode("utf-8"),
            bcrypt.gensalt()
        ).decode("utf-8")

        cursor.execute(
            "UPDATE login SET contrasena = %s WHERE correo = %s",
            (password_hash, correo)
        )

        if cursor.rowcount != 1:
            raise ValueError(f"No se encontró el usuario {correo}")

    conexion.commit()
    print("¡Contraseñas configuradas correctamente!")

except Exception as error:
    if conexion is not None:
        conexion.rollback()
    print("Error:", error)

finally:
    if cursor is not None:
        cursor.close()
    if conexion is not None:
        conexion.close()
