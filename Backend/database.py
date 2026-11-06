
import os
import mysql.connector
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))


def obtener_conexion(rol=None):
    """
    Abre una conexión a MySQL según el rol indicado.

    rol=None: conexión predeterminada (compatibilidad)
    rol="login": usuario de autenticación
    rol="administrador": usuario administrador
    rol="planillero": usuario planillero
    """

    credenciales = {
        "login": ("DB_LOGIN_USER", "DB_LOGIN_PASSWORD"),
        "administrador": ("DB_ADMIN_USER", "DB_ADMIN_PASSWORD"),
        "planillero": ("DB_PLANILLERO_USER", "DB_PLANILLERO_PASSWORD")
    }

    if rol is None:
        usuario = os.getenv("DB_USER")
        password = os.getenv("DB_PASSWORD")
    else:
        if rol not in credenciales:
            raise ValueError("Rol de conexión inválido")

        variable_usuario, variable_password = credenciales[rol]
        usuario = os.getenv(variable_usuario)
        password = os.getenv(variable_password)

    if not usuario or not password:
        raise RuntimeError(
            f"Faltan credenciales MySQL para el rol: {rol}"
        )

    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", 3306)),
        user=usuario,
        password=password,
        database=os.getenv("DB_NAME")
    )
