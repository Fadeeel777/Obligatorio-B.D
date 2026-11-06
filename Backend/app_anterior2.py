
import os
import bcrypt

from flask import Flask, jsonify, request, session
from dotenv import load_dotenv
from database import obtener_conexion
from functools import wraps
from datetime import date
from mysql.connector import IntegrityError


load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

app = Flask(__name__)

app.secret_key = os.getenv("FLASK_SECRET_KEY")

if not app.secret_key:
    raise RuntimeError("Falta FLASK_SECRET_KEY en el archivo .env")

def requiere_rol(*roles_permitidos):
    def decorador(funcion):
        @wraps(funcion)
        def verificar(*args, **kwargs):
            if "correo" not in session:
                return jsonify({
                    "error": "Debes iniciar sesión"
                }), 401

            if session.get("rol") not in roles_permitidos:
                return jsonify({
                    "error": "No tienes permisos"
                }), 403

            return funcion(*args, **kwargs)

        return verificar
    return decorador



@app.route("/")
def inicio():
    return jsonify({
        "mensaje": "Backend funcionando correctamente"
    })


@app.route("/facultades", methods=["GET"])
def listar_facultades():
    conexion = None
    cursor = None

    try:
        conexion = obtener_conexion()
        cursor = conexion.cursor(dictionary=True)

        cursor.execute(
            "SELECT id_facultad, nombre FROM facultad ORDER BY nombre"
        )

        facultades = cursor.fetchall()
        return jsonify(facultades)

    except Exception as error:
        print("Error al consultar facultades:", error)
        return jsonify({"error": "Error interno"}), 500

    finally:
        if cursor is not None:
            cursor.close()
        if conexion is not None:
            conexion.close()


@app.route("/login", methods=["POST"])
def login():
    datos = request.get_json(silent=True) or {}

    correo = datos.get("correo", "")
    password = datos.get("password", "")

    if not isinstance(correo, str) or not isinstance(password, str):
        return jsonify({"error": "Datos inválidos"}), 400

    correo = correo.strip()

    if not correo or not password:
        return jsonify({"error": "Correo y contraseña obligatorios"}), 400

    conexion = None
    cursor = None

    try:
        conexion = obtener_conexion()
        cursor = conexion.cursor(dictionary=True)

        cursor.execute(
            "SELECT correo, contrasena, rol FROM login WHERE correo = %s",
            (correo,)
        )

        usuario = cursor.fetchone()

        if usuario is None:
            return jsonify({"error": "Credenciales incorrectas"}), 401

        password_correcta = bcrypt.checkpw(
            password.encode("utf-8"),
            usuario["contrasena"].encode("utf-8")
        )

        if not password_correcta:
            return jsonify({"error": "Credenciales incorrectas"}), 401

        session.clear()
        session["correo"] = usuario["correo"]
        session["rol"] = usuario["rol"]

        return jsonify({
            "mensaje": "Login exitoso",
            "correo": usuario["correo"],
            "rol": usuario["rol"]
        })

    except Exception as error:
        print("Error en login:", error)
        return jsonify({"error": "Error interno"}), 500

    finally:
        if cursor is not None:
            cursor.close()
        if conexion is not None:
            conexion.close()


@app.route("/perfil", methods=["GET"])
def perfil():
    if "correo" not in session:
        return jsonify({"error": "No autenticado"}), 401

    return jsonify({
        "correo": session["correo"],
        "rol": session["rol"]
    })


@app.route("/logout", methods=["POST"])
def logout():
    session.clear()

    return jsonify({
        "mensaje": "Sesión cerrada correctamente"
    })


@app.route("/admin/prueba", methods=["GET"])
@requiere_rol("administrador")
def prueba_admin():
    return jsonify({
        "mensaje": "Acceso autorizado para administrador"
    })


TIPOS_JUGADOR = {"grado", "posgrado", "docente", "funcionario"}


def validar_jugador(datos):
    campos = [
        "ci", "nombre", "apellido", "email",
        "fecha_nacimiento", "id_facultad", "tipo"
    ]

    if not isinstance(datos, dict):
        return "Los datos deben ser un objeto JSON"

    for campo in campos:
        if campo not in datos or datos[campo] is None:
            return f"Falta el campo {campo}"

    for campo, limite in [
        ("ci", 8), ("nombre", 50),
        ("apellido", 50), ("email", 100)
    ]:
        valor = datos[campo]

        if not isinstance(valor, str) or not valor.strip():
            return f"El campo {campo} no es válido"

        if len(valor) > limite:
            return f"El campo {campo} supera {limite} caracteres"

    if not datos["ci"].isdigit():
        return "La CI debe contener solo números"

    if "@" not in datos["email"]:
        return "El correo no es válido"

    if datos["tipo"] not in TIPOS_JUGADOR:
        return "Tipo de jugador inválido"

    try:
        nacimiento = date.fromisoformat(datos["fecha_nacimiento"])
        if nacimiento > date.today():
            return "La fecha de nacimiento no puede ser futura"
    except (ValueError, TypeError):
        return "La fecha debe tener formato AAAA-MM-DD"

    if (type(datos["id_facultad"]) is not int
            or datos["id_facultad"] <= 0):
        return "La facultad debe ser un número entero positivo"

    return None


@app.route("/jugadores", methods=["GET"])
@requiere_rol("administrador")
def listar_jugadores():
    conexion = None
    cursor = None

    try:
        conexion = obtener_conexion()
        cursor = conexion.cursor(dictionary=True)

        cursor.execute("""
            SELECT j.ci, j.nombre, j.apellido, j.email,
                   j.fecha_nacimiento, j.id_facultad,
                   f.nombre AS facultad, j.tipo
            FROM jugador j
            JOIN facultad f ON j.id_facultad = f.id_facultad
            ORDER BY j.apellido, j.nombre
        """)

        return jsonify(cursor.fetchall())

    except Exception as error:
        print("Error al listar jugadores:", error)
        return jsonify({"error": "Error interno"}), 500

    finally:
        if cursor:
            cursor.close()
        if conexion:
            conexion.close()


@app.route("/jugadores", methods=["POST"])
@requiere_rol("administrador")
def crear_jugador():
    datos = request.get_json(silent=True)
    error = validar_jugador(datos)

    if error:
        return jsonify({"error": error}), 400

    conexion = None
    cursor = None

    try:
        conexion = obtener_conexion()
        cursor = conexion.cursor()

        cursor.execute("""
            INSERT INTO jugador
            (ci, nombre, apellido, email,
             fecha_nacimiento, id_facultad, tipo)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (
            datos["ci"], datos["nombre"], datos["apellido"],
            datos["email"], datos["fecha_nacimiento"],
            datos["id_facultad"], datos["tipo"]
        ))

        conexion.commit()

        return jsonify({
            "mensaje": "Jugador creado correctamente"
        }), 201

    except IntegrityError as error:
        if conexion:
            conexion.rollback()
        print("Error de integridad:", error)
        return jsonify({
            "error": "CI o correo duplicado, o facultad inexistente"
        }), 409

    except Exception as error:
        if conexion:
            conexion.rollback()
        print("Error al crear jugador:", error)
        return jsonify({"error": "Error interno"}), 500

    finally:
        if cursor:
            cursor.close()
        if conexion:
            conexion.close()


@app.route("/jugadores/<ci>", methods=["PUT"])
@requiere_rol("administrador")
def modificar_jugador(ci):
    datos = request.get_json(silent=True)

    if not isinstance(datos, dict):
        return jsonify({"error": "JSON inválido"}), 400

    datos["ci"] = ci
    error = validar_jugador(datos)

    if error:
        return jsonify({"error": error}), 400

    conexion = None
    cursor = None

    try:
        conexion = obtener_conexion()
        cursor = conexion.cursor()

        cursor.execute("""
            UPDATE jugador
            SET nombre = %s,
                apellido = %s,
                email = %s,
                fecha_nacimiento = %s,
                id_facultad = %s,
                tipo = %s
            WHERE ci = %s
        """, (
            datos["nombre"], datos["apellido"],
            datos["email"], datos["fecha_nacimiento"],
            datos["id_facultad"], datos["tipo"], ci
        ))

        if cursor.rowcount == 0:
            cursor.execute(
                "SELECT ci FROM jugador WHERE ci = %s",
                (ci,)
            )
            if cursor.fetchone() is None:
                return jsonify({"error": "Jugador no encontrado"}), 404

        conexion.commit()
        return jsonify({"mensaje": "Jugador actualizado"})

    except IntegrityError as error:
        if conexion:
            conexion.rollback()
        print("Error de integridad:", error)
        return jsonify({
            "error": "Correo duplicado o facultad inexistente"
        }), 409

    except Exception as error:
        if conexion:
            conexion.rollback()
        print("Error al modificar jugador:", error)
        return jsonify({"error": "Error interno"}), 500

    finally:
        if cursor:
            cursor.close()
        if conexion:
            conexion.close()


@app.route("/jugadores/<ci>", methods=["DELETE"])
@requiere_rol("administrador")
def eliminar_jugador(ci):
    conexion = None
    cursor = None

    try:
        conexion = obtener_conexion()
        cursor = conexion.cursor()

        cursor.execute(
            "DELETE FROM jugador WHERE ci = %s",
            (ci,)
        )

        if cursor.rowcount == 0:
            return jsonify({"error": "Jugador no encontrado"}), 404

        conexion.commit()
        return jsonify({"mensaje": "Jugador eliminado"})

    except IntegrityError:
        if conexion:
            conexion.rollback()
        return jsonify({
            "error": "No se puede eliminar: el jugador tiene registros asociados"
        }), 409

    except Exception as error:
        if conexion:
            conexion.rollback()
        print("Error al eliminar jugador:", error)
        return jsonify({"error": "Error interno"}), 500

    finally:
        if cursor:
            cursor.close()
        if conexion:
            conexion.close()


# ==========================================
# TORNEOS, FECHAS, EQUIPOS Y PLANTELES
# ==========================================

from datetime import datetime
from mysql.connector import IntegrityError


def datos_json():
    datos = request.get_json(silent=True)
    if not isinstance(datos, dict):
        return None
    return datos


def fecha_valida(valor):
    try:
        return datetime.strptime(valor, "%Y-%m-%d").date()
    except (ValueError, TypeError):
        return None


def numero_entero(valor):
    try:
        if isinstance(valor, bool):
            return None
        return int(valor)
    except (ValueError, TypeError):
        return None


def error_integridad(error):
    return jsonify({
        "error": "La operación incumple una restricción de la base de datos",
        "detalle": str(error)
    }), 409


# -------- TORNEOS --------

@app.route("/torneos", methods=["GET"])
@requiere_rol("administrador", "planillero")
def listar_torneos():
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM torneo ORDER BY anio DESC, semestre DESC")
        return jsonify(cursor.fetchall())
    finally:
        cursor.close()
        conexion.close()


@app.route("/torneos", methods=["POST"])
@requiere_rol("administrador")
def crear_torneo():
    datos = datos_json()
    if datos is None:
        return jsonify({"error": "Se requiere un JSON válido"}), 400

    nombre = str(datos.get("nombre") or "").strip()
    anio = numero_entero(datos.get("anio"))
    semestre = numero_entero(datos.get("semestre"))
    inicio = fecha_valida(datos.get("fecha_inicio"))
    fin = fecha_valida(datos.get("fecha_fin"))

    if not nombre or len(nombre) > 100:
        return jsonify({"error": "Nombre inválido"}), 400
    if anio is None or not 2000 <= anio <= 2100:
        return jsonify({"error": "Año inválido"}), 400
    if semestre not in (1, 2):
        return jsonify({"error": "El semestre debe ser 1 o 2"}), 400
    if not inicio or not fin or inicio > fin:
        return jsonify({"error": "Fechas inválidas"}), 400

    conexion = obtener_conexion()
    cursor = conexion.cursor()
    try:
        cursor.execute("""
            INSERT INTO torneo
            (nombre, anio, semestre, fecha_inicio, fecha_fin)
            VALUES (%s, %s, %s, %s, %s)
        """, (nombre, anio, semestre, inicio, fin))
        conexion.commit()
        return jsonify({
            "mensaje": "Torneo creado",
            "id_torneo": cursor.lastrowid
        }), 201
    except IntegrityError as error:
        conexion.rollback()
        return error_integridad(error)
    finally:
        cursor.close()
        conexion.close()


# -------- FECHAS DEL TORNEO --------

@app.route("/torneos/<int:id_torneo>/fechas", methods=["GET"])
@requiere_rol("administrador", "planillero")
def listar_fechas(id_torneo):
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT * FROM fecha_torneo
            WHERE id_torneo = %s
            ORDER BY numero_fecha
        """, (id_torneo,))
        return jsonify(cursor.fetchall())
    finally:
        cursor.close()
        conexion.close()


@app.route("/torneos/<int:id_torneo>/fechas", methods=["POST"])
@requiere_rol("administrador")
def crear_fecha(id_torneo):
    datos = datos_json()
    if datos is None:
        return jsonify({"error": "JSON inválido"}), 400

    numero = numero_entero(datos.get("numero_fecha"))
    desde = fecha_valida(datos.get("fecha_desde"))
    hasta = fecha_valida(datos.get("fecha_hasta"))

    if numero is None or numero < 1 or not desde or not hasta or desde > hasta:
        return jsonify({"error": "Datos de fecha inválidos"}), 400

    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT fecha_inicio, fecha_fin
            FROM torneo WHERE id_torneo = %s
        """, (id_torneo,))
        torneo = cursor.fetchone()

        if not torneo:
            return jsonify({"error": "Torneo inexistente"}), 404

        if desde < torneo["fecha_inicio"] or hasta > torneo["fecha_fin"]:
            return jsonify({
                "error": "La fecha debe estar dentro del período del torneo"
            }), 400

        cursor.execute("""
            INSERT INTO fecha_torneo
            (id_torneo, numero_fecha, fecha_desde, fecha_hasta)
            VALUES (%s, %s, %s, %s)
        """, (id_torneo, numero, desde, hasta))

        conexion.commit()
        return jsonify({"mensaje": "Fecha creada"}), 201

    except IntegrityError as error:
        conexion.rollback()
        return error_integridad(error)
    finally:
        cursor.close()
        conexion.close()


# -------- EQUIPOS --------

@app.route("/equipos", methods=["GET"])
@requiere_rol("administrador", "planillero")
def listar_equipos():
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT e.*, f.nombre AS facultad, t.nombre AS torneo
            FROM equipo e
            JOIN facultad f ON e.id_facultad = f.id_facultad
            JOIN torneo t ON e.id_torneo = t.id_torneo
            ORDER BY e.id_equipo
        """)
        return jsonify(cursor.fetchall())
    finally:
        cursor.close()
        conexion.close()


@app.route("/equipos", methods=["POST"])
@requiere_rol("administrador")
def crear_equipo():
    datos = datos_json()
    if datos is None:
        return jsonify({"error": "JSON inválido"}), 400

    nombre = str(datos.get("nombre") or "").strip()
    id_torneo = numero_entero(datos.get("id_torneo"))
    id_facultad = numero_entero(datos.get("id_facultad"))

    if not nombre or len(nombre) > 100:
        return jsonify({"error": "Nombre inválido"}), 400
    if not id_torneo or id_torneo < 1 or not id_facultad or id_facultad < 1:
        return jsonify({"error": "Torneo o facultad inválidos"}), 400

    conexion = obtener_conexion()
    cursor = conexion.cursor()
    try:
        cursor.execute("""
            INSERT INTO equipo (nombre, id_torneo, id_facultad)
            VALUES (%s, %s, %s)
        """, (nombre, id_torneo, id_facultad))
        conexion.commit()

        return jsonify({
            "mensaje": "Equipo creado",
            "id_equipo": cursor.lastrowid
        }), 201

    except IntegrityError as error:
        conexion.rollback()
        return error_integridad(error)
    finally:
        cursor.close()
        conexion.close()


@app.route("/equipos/<int:id_equipo>", methods=["PUT"])
@requiere_rol("administrador")
def modificar_equipo(id_equipo):
    datos = datos_json()
    if datos is None:
        return jsonify({"error": "JSON inválido"}), 400

    nombre = str(datos.get("nombre") or "").strip()

    if not nombre or len(nombre) > 100:
        return jsonify({"error": "Nombre inválido"}), 400

    conexion = obtener_conexion()
    cursor = conexion.cursor()
    try:
        cursor.execute("""
            UPDATE equipo SET nombre = %s
            WHERE id_equipo = %s
        """, (nombre, id_equipo))

        if cursor.rowcount == 0:
            cursor.execute(
                "SELECT id_equipo FROM equipo WHERE id_equipo = %s",
                (id_equipo,)
            )
            if cursor.fetchone() is None:
                return jsonify({"error": "Equipo inexistente"}), 404

        conexion.commit()
        return jsonify({"mensaje": "Equipo actualizado"})

    except IntegrityError as error:
        conexion.rollback()
        return error_integridad(error)
    finally:
        cursor.close()
        conexion.close()


@app.route("/equipos/<int:id_equipo>", methods=["DELETE"])
@requiere_rol("administrador")
def eliminar_equipo(id_equipo):
    conexion = obtener_conexion()
    cursor = conexion.cursor()
    try:
        cursor.execute(
            "DELETE FROM equipo WHERE id_equipo = %s",
            (id_equipo,)
        )

        if cursor.rowcount == 0:
            return jsonify({"error": "Equipo inexistente"}), 404

        conexion.commit()
        return jsonify({"mensaje": "Equipo eliminado"})

    except IntegrityError as error:
        conexion.rollback()
        return error_integridad(error)
    finally:
        cursor.close()
        conexion.close()


# -------- INSCRIPCIÓN DE JUGADORES --------

@app.route("/equipos/<int:id_equipo>/jugadores", methods=["GET"])
@requiere_rol("administrador", "planillero")
def jugadores_equipo(id_equipo):
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT j.ci, j.nombre, j.apellido,
                   ej.numero_camiseta
            FROM equipo_jugador_torneo ej
            JOIN jugador j ON j.ci = ej.ci_jugador
            WHERE ej.id_equipo = %s
            ORDER BY ej.numero_camiseta
        """, (id_equipo,))
        return jsonify(cursor.fetchall())
    finally:
        cursor.close()
        conexion.close()


@app.route("/equipos/<int:id_equipo>/jugadores", methods=["POST"])
@requiere_rol("administrador")
def inscribir_jugador(id_equipo):
    datos = datos_json()
    if datos is None:
        return jsonify({"error": "JSON inválido"}), 400

    ci = str(datos.get("ci_jugador") or "").strip()
    camiseta = numero_entero(datos.get("numero_camiseta"))

    if not ci or len(ci) > 8:
        return jsonify({"error": "CI inválida"}), 400
    if camiseta is None or not 1 <= camiseta <= 99:
        return jsonify({"error": "Camiseta debe estar entre 1 y 99"}), 400

    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT id_torneo, id_facultad
            FROM equipo WHERE id_equipo = %s
        """, (id_equipo,))
        equipo = cursor.fetchone()

        if not equipo:
            return jsonify({"error": "Equipo inexistente"}), 404

        cursor.execute("""
            SELECT id_facultad FROM jugador WHERE ci = %s
        """, (ci,))
        jugador = cursor.fetchone()

        if not jugador:
            return jsonify({"error": "Jugador inexistente"}), 404

        if jugador["id_facultad"] != equipo["id_facultad"]:
            return jsonify({
                "error": "El jugador debe pertenecer a la facultad del equipo"
            }), 400

        cursor.execute("""
            INSERT INTO equipo_jugador_torneo
            (id_equipo, ci_jugador, id_torneo, numero_camiseta)
            VALUES (%s, %s, %s, %s)
        """, (id_equipo, ci, equipo["id_torneo"], camiseta))

        conexion.commit()
        return jsonify({"mensaje": "Jugador inscrito"}), 201

    except IntegrityError as error:
        conexion.rollback()
        return error_integridad(error)
    finally:
        cursor.close()
        conexion.close()


@app.route("/equipos/<int:id_equipo>/jugadores/<ci>", methods=["DELETE"])
@requiere_rol("administrador")
def quitar_jugador(id_equipo, ci):
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT ci_capitan FROM equipo
            WHERE id_equipo = %s
        """, (id_equipo,))
        equipo = cursor.fetchone()

        if not equipo:
            return jsonify({"error": "Equipo inexistente"}), 404

        if equipo["ci_capitan"] == ci:
            return jsonify({
                "error": "Primero hay que cambiar o quitar al capitán"
            }), 400

        cursor.execute("""
            DELETE FROM equipo_jugador_torneo
            WHERE id_equipo = %s AND ci_jugador = %s
        """, (id_equipo, ci))

        if cursor.rowcount == 0:
            return jsonify({"error": "Inscripción inexistente"}), 404

        conexion.commit()
        return jsonify({"mensaje": "Jugador quitado del equipo"})

    except IntegrityError as error:
        conexion.rollback()
        return error_integridad(error)
    finally:
        cursor.close()
        conexion.close()


# -------- CAPITÁN --------

@app.route("/equipos/<int:id_equipo>/capitan", methods=["PUT"])
@requiere_rol("administrador")
def asignar_capitan(id_equipo):
    datos = datos_json()
    if datos is None:
        return jsonify({"error": "JSON inválido"}), 400

    ci = datos.get("ci_capitan")
    if ci is not None:
        ci = str(ci).strip()
        if not ci or len(ci) > 8:
            return jsonify({"error": "CI inválida"}), 400

    conexion = obtener_conexion()
    cursor = conexion.cursor()
    try:
        cursor.execute(
            "SELECT id_equipo FROM equipo WHERE id_equipo = %s",
            (id_equipo,)
        )
        if cursor.fetchone() is None:
            return jsonify({"error": "Equipo inexistente"}), 404

        if ci is not None:
            cursor.execute("""
                SELECT 1 FROM equipo_jugador_torneo
                WHERE id_equipo = %s AND ci_jugador = %s
            """, (id_equipo, ci))

            if cursor.fetchone() is None:
                return jsonify({
                    "error": "El capitán debe estar inscrito en el equipo"
                }), 400

        cursor.execute("""
            UPDATE equipo SET ci_capitan = %s
            WHERE id_equipo = %s
        """, (ci, id_equipo))

        conexion.commit()
        return jsonify({"mensaje": "Capitán actualizado"})

    except IntegrityError as error:
        conexion.rollback()
        return error_integridad(error)
    finally:
        cursor.close()
        conexion.close()

# ==========================================
# PARTIDOS, PLANILLAS, GOLES Y TARJETAS
# ==========================================

from datetime import datetime


# -------- CANCHAS Y TURNOS --------

@app.route("/canchas", methods=["GET"])
@requiere_rol("administrador", "planillero")
def listar_canchas():
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT nombre_cancha, id_complejo, superficie, techada
            FROM cancha
            ORDER BY id_complejo, nombre_cancha
        """)
        return jsonify(cursor.fetchall())
    finally:
        cursor.close()
        conexion.close()


@app.route("/turnos", methods=["GET"])
@requiere_rol("administrador", "planillero")
def listar_turnos():
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM turno ORDER BY hora_inicio")
        turnos = cursor.fetchall()

        for turno in turnos:
            turno["hora_inicio"] = str(turno["hora_inicio"])
            turno["hora_fin"] = str(turno["hora_fin"])

        return jsonify(turnos)
    finally:
        cursor.close()
        conexion.close()


# -------- PROGRAMAR PARTIDOS --------

@app.route("/partidos", methods=["GET"])
@requiere_rol("administrador", "planillero")
def listar_partidos():
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT p.*, el.nombre AS equipo_local,
                   ev.nombre AS equipo_visitante
            FROM partido p
            JOIN equipo el ON el.id_equipo = p.id_equipo_local
            JOIN equipo ev ON ev.id_equipo = p.id_equipo_visitante
            ORDER BY p.dia, p.id_turno
        """)
        return jsonify(cursor.fetchall())
    finally:
        cursor.close()
        conexion.close()


@app.route("/partidos", methods=["POST"])
@requiere_rol("administrador")
def crear_partido():
    datos = datos_json()
    if datos is None:
        return jsonify({"error": "JSON inválido"}), 400

    campos = ("id_torneo", "numero_fecha", "id_equipo_local",
              "id_equipo_visitante", "id_turno", "id_complejo")
    valores = [numero_entero(datos.get(c)) for c in campos]
    dia = fecha_valida(datos.get("dia"))
    cancha = datos.get("nombre_cancha")
    if (any(v is None or v < 1 for v in valores) or not dia
            or not isinstance(cancha, str) or not cancha.strip()
            or len(cancha.strip()) > 50):
        return jsonify({"error": "Datos del partido inválidos"}), 400

    try:
        resultados = ejecutar_procedimiento("sp_programar_partido", [
            valores[0], valores[1], valores[2], valores[3],
            dia, valores[4], cancha.strip(), valores[5]
        ])
        return jsonify({"mensaje": "Partido programado", "resultados": resultados}), 201
    except Error as error:
        return error_procedimiento(error)



# -------- PLANILLAS --------

@app.route("/partidos/<int:id_partido>/planilla", methods=["GET"])
@requiere_rol("administrador", "planillero")
def consultar_planilla(id_partido):
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)

    try:
        cursor.execute("""
            SELECT pp.id_partido, pp.id_equipo, pp.ci_jugador,
                   j.nombre, j.apellido
            FROM planilla_partido pp
            JOIN jugador j ON j.ci = pp.ci_jugador
            WHERE pp.id_partido = %s
            ORDER BY pp.id_equipo, j.apellido
        """, (id_partido,))

        return jsonify(cursor.fetchall())
    finally:
        cursor.close()
        conexion.close()


@app.route("/partidos/<int:id_partido>/planilla", methods=["POST"])
@requiere_rol("administrador", "planillero")
def agregar_jugador_planilla(id_partido):
    datos = datos_json()
    if datos is None:
        return jsonify({"error": "JSON inválido"}), 400
    ci = datos.get("ci_jugador")
    if not isinstance(ci, str) or not ci.isdigit() or not 1 <= len(ci) <= 8:
        return jsonify({"error": "CI inválida"}), 400
    try:
        resultados = ejecutar_procedimiento("sp_agregar_a_planilla", [id_partido, ci])
        return jsonify({"mensaje": "Jugador agregado a la planilla", "resultados": resultados}), 201
    except Error as error:
        return error_procedimiento(error)



# -------- GOLES --------

@app.route("/partidos/<int:id_partido>/goles", methods=["POST"])
@requiere_rol("administrador", "planillero")
def registrar_gol(id_partido):
    datos = datos_json()
    if datos is None:
        return jsonify({"error": "JSON inválido"}), 400
    ci = datos.get("ci_jugador")
    minuto = numero_entero(datos.get("minuto"))
    autogol = datos.get("autogol", False)
    if (not isinstance(ci, str) or not ci.isdigit() or not 1 <= len(ci) <= 8
            or minuto is None or not 0 <= minuto <= 60
            or not isinstance(autogol, bool)):
        return jsonify({"error": "Datos del gol inválidos"}), 400
    try:
        resultados = ejecutar_procedimiento("sp_registrar_gol", [
            id_partido, ci, minuto, int(autogol)
        ])
        return jsonify({"mensaje": "Gol registrado", "resultados": resultados}), 201
    except Error as error:
        return error_procedimiento(error)



# -------- TARJETAS --------

@app.route("/partidos/<int:id_partido>/tarjetas", methods=["POST"])
@requiere_rol("administrador", "planillero")
def registrar_tarjeta(id_partido):
    datos = datos_json()
    if datos is None:
        return jsonify({"error": "JSON inválido"}), 400
    ci = datos.get("ci_jugador")
    minuto = numero_entero(datos.get("minuto"))
    color = datos.get("color")
    if (not isinstance(ci, str) or not ci.isdigit() or not 1 <= len(ci) <= 8
            or minuto is None or not 0 <= minuto <= 60
            or color not in ("amarilla", "roja")):
        return jsonify({"error": "Datos de la tarjeta inválidos"}), 400
    try:
        resultados = ejecutar_procedimiento("sp_registrar_tarjeta", [
            id_partido, ci, minuto, color
        ])
        return jsonify({"mensaje": "Tarjeta registrada", "resultados": resultados}), 201
    except Error as error:
        return error_procedimiento(error)



# -------- CONSULTAR GOLES Y TARJETAS --------

@app.route("/partidos/<int:id_partido>/eventos", methods=["GET"])
@requiere_rol("administrador", "planillero")
def consultar_eventos(id_partido):
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)

    try:
        cursor.execute("""
            SELECT g.*, j.nombre, j.apellido, pp.id_equipo
            FROM gol g
            JOIN jugador j ON j.ci = g.ci_jugador
            JOIN planilla_partido pp
              ON pp.id_partido = g.id_partido
             AND pp.ci_jugador = g.ci_jugador
            WHERE g.id_partido = %s
            ORDER BY g.minuto
        """, (id_partido,))
        goles = cursor.fetchall()

        cursor.execute("""
            SELECT t.*, j.nombre, j.apellido
            FROM tarjeta t
            JOIN jugador j ON j.ci = t.ci_jugador
            WHERE t.id_partido = %s
            ORDER BY t.minuto
        """, (id_partido,))
        tarjetas = cursor.fetchall()

        return jsonify({
            "goles": goles,
            "tarjetas": tarjetas
        })
    finally:
        cursor.close()
        conexion.close()


# -------- FINALIZAR PARTIDO --------

@app.route("/partidos/<int:id_partido>/finalizar", methods=["PUT"])
@requiere_rol("administrador", "planillero")
def finalizar_partido(id_partido):
    try:
        resultados = ejecutar_procedimiento("sp_marcar_partido_jugado", [id_partido])
        return jsonify({"mensaje": "Partido marcado como jugado", "resultados": resultados})
    except Error as error:
        return error_procedimiento(error)



from mysql.connector import Error


def ejecutar_procedimiento(nombre, parametros):
    """
    Ejecuta un procedimiento almacenado y devuelve
    los resultados de sus SELECT, si existen.
    """
    permitidos = {
        "sp_programar_partido",
        "sp_agregar_a_planilla",
        "sp_quitar_de_planilla",
        "sp_registrar_gol",
        "sp_eliminar_gol",
        "sp_registrar_tarjeta",
        "sp_eliminar_tarjeta",
        "sp_marcar_partido_jugado",
        "sp_sancion_disciplinaria",
        "sp_cambiar_estado_torneo",
    }

    if nombre not in permitidos:
        raise ValueError("Procedimiento no permitido")

    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)

    try:
        marcadores = ", ".join(["%s"] * len(parametros))
        consulta = f"CALL {nombre}({marcadores})"

        cursor.execute(consulta, tuple(parametros))

        resultados = []
        while True:
            if cursor.with_rows:
                resultados.extend(cursor.fetchall())

            if not cursor.nextset():
                break

        conexion.commit()
        return resultados

    except Error:
        conexion.rollback()
        raise

    finally:
        cursor.close()
        conexion.close()

@app.route("/torneos/<int:id_torneo>/estado", methods=["PUT"])
@requiere_rol("administrador")
def cambiar_estado_torneo(id_torneo):
    datos = request.get_json(silent=True)

    if not isinstance(datos, dict):
        return jsonify({"error": "JSON inválido"}), 400

    estado = datos.get("estado")

    if estado not in ("en_curso", "finalizado"):
        return jsonify({"error": "Estado inválido"}), 400

    try:
        ejecutar_procedimiento(
            "sp_cambiar_estado_torneo",
            [id_torneo, estado]
        )

        return jsonify({"mensaje": "Estado actualizado"})

    except Error as error:
        return jsonify({"error": str(error)}), 400



# Operaciones adicionales mediante procedimientos almacenados.
def error_procedimiento(error):
    # Errores de reglas SQL (SIGNAL) y restricciones se presentan como errores de usuario.
    codigo = 409 if getattr(error, "errno", None) in (1062, 1451, 1452, 1644, 3819) else 400
    return jsonify({"error": "Operación rechazada por MySQL", "detalle": str(error)}), codigo


@app.route("/partidos/<int:id_partido>/planilla/<ci>", methods=["DELETE"])
@requiere_rol("administrador", "planillero")
def quitar_de_planilla(id_partido, ci):
    try:
        ejecutar_procedimiento("sp_quitar_de_planilla", [id_partido, ci])
        return jsonify({"mensaje": "Jugador quitado de la planilla"})
    except Error as error:
        return error_procedimiento(error)


@app.route("/goles/<int:id_gol>", methods=["DELETE"])
@requiere_rol("administrador", "planillero")
def eliminar_gol(id_gol):
    try:
        ejecutar_procedimiento("sp_eliminar_gol", [id_gol])
        return jsonify({"mensaje": "Gol eliminado"})
    except Error as error:
        return error_procedimiento(error)


@app.route("/tarjetas/<int:id_tarjeta>", methods=["DELETE"])
@requiere_rol("administrador", "planillero")
def eliminar_tarjeta(id_tarjeta):
    try:
        ejecutar_procedimiento("sp_eliminar_tarjeta", [id_tarjeta])
        return jsonify({"mensaje": "Tarjeta eliminada"})
    except Error as error:
        return error_procedimiento(error)


@app.route("/sanciones/disciplinarias", methods=["POST"])
@requiere_rol("administrador")
def crear_sancion_disciplinaria():
    datos = datos_json()
    if datos is None:
        return jsonify({"error": "JSON inválido"}), 400
    ci = datos.get("ci_jugador")
    torneo = numero_entero(datos.get("id_torneo"))
    fecha = numero_entero(datos.get("numero_fecha_inicio"))
    cantidad = numero_entero(datos.get("cantidad_fechas"))
    if (not isinstance(ci, str) or not ci.isdigit() or not 1 <= len(ci) <= 8
            or any(v is None or v < 1 for v in (torneo, fecha, cantidad))):
        return jsonify({"error": "Datos de sanción inválidos"}), 400
    try:
        resultados = ejecutar_procedimiento("sp_sancion_disciplinaria", [ci, torneo, fecha, cantidad])
        return jsonify({"mensaje": "Sanción registrada", "resultados": resultados}), 201
    except Error as error:
        return error_procedimiento(error)


# Reportes: nombres fijos para evitar SQL dinámico no confiable.
VISTAS_REPORTE = {
    "v_disciplina_jugador", "v_equipo_partido", "v_fair_play",
    "v_goleadores", "v_jugadores_por_facultad_tipo",
    "v_jugadores_sin_planilla", "v_partido_detalle",
    "v_porcentaje_partidos", "v_promedio_goles_por_edicion",
    "v_promedio_goles_por_fecha", "v_resultado_partido",
    "v_sanciones_por_equipo_motivo", "v_suspendidos_por_fecha",
    "v_tabla_posiciones", "v_uso_canchas", "v_uso_turnos",
    "v_valla_menos_vencida",
}


@app.route("/reportes", methods=["GET"])
@requiere_rol("administrador", "planillero")
def listar_reportes():
    return jsonify(sorted(VISTAS_REPORTE))


@app.route("/reportes/<nombre>", methods=["GET"])
@requiere_rol("administrador", "planillero")
def consultar_reporte(nombre):
    if nombre not in VISTAS_REPORTE:
        return jsonify({"error": "Reporte inexistente"}), 404
    conexion = None
    cursor = None
    try:
        conexion = obtener_conexion()
        cursor = conexion.cursor(dictionary=True)
        cursor.execute(f"SELECT * FROM `{nombre}`")
        return jsonify(cursor.fetchall())
    except Error as error:
        app.logger.exception("Error en reporte %s", nombre)
        return jsonify({"error": "No se pudo consultar el reporte"}), 500
    finally:
        if cursor is not None:
            cursor.close()
        if conexion is not None:
            conexion.close()


if __name__ == "__main__":
    app.run(debug=True)
