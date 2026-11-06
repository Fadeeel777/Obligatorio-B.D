"""Auditoría local no destructiva del backend del torneo.
Ejecutar desde la raíz: python auditar_backend.py
No crea, modifica ni elimina registros. No prueba el login con contraseña.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'Backend'))

try:
    from app import app, VISTAS_REPORTE
    from database import obtener_conexion
except Exception as exc:
    print(f'ERROR al importar: {type(exc).__name__}: {exc}')
    raise SystemExit(1)

fallos = []
aciertos = 0

def verificar(nombre, condicion, detalle=''):
    global aciertos
    estado = 'OK' if condicion else 'FALLO'
    print(f'[{estado}] {nombre}' + (f' — {detalle}' if detalle else ''))
    if condicion:
        aciertos += 1
    else:
        fallos.append(nombre)


def cliente(rol=None):
    c = app.test_client()
    if rol:
        # Sesión de prueba local: verifica decoradores, NO autentica usuarios reales.
        with c.session_transaction() as s:
            s['correo'] = 'auditoria@local.test'
            s['rol'] = rol
    return c

print('\n=== 1. RUTAS Y CONTROL DE ACCESO ===')
reglas = [r for r in app.url_map.iter_rules() if r.endpoint != 'static']
pares = [(r.rule, metodo) for r in reglas for metodo in r.methods if metodo not in ('HEAD','OPTIONS')]
verificar('Sin rutas duplicadas', len(pares) == len(set(pares)), f'{len(pares)} combinaciones ruta/método')

admin = cliente('administrador')
planillero = cliente('planillero')
anonimo = cliente()

rutas_lectura = ['/facultades', '/torneos', '/equipos', '/canchas', '/turnos', '/partidos', '/reportes', '/torneos/1/fechas', '/equipos/1/jugadores', '/partidos/1/planilla', '/partidos/1/eventos']
for ruta in rutas_lectura:
    resp = admin.get(ruta)
    verificar('GET '+ruta, resp.status_code == 200, f'HTTP {resp.status_code}')

verificar('Anónimo no accede a reportes', anonimo.get('/reportes').status_code == 401)
verificar('Planillero puede leer reportes', planillero.get('/reportes').status_code == 200)
verificar('Planillero no accede a /admin/prueba', planillero.get('/admin/prueba').status_code == 403)

# Solicitudes sin JSON: deben rechazarse antes de ejecutar cualquier escritura.
solo_admin = [('POST','/torneos'), ('POST','/equipos'), ('POST','/jugadores'), ('POST','/partidos'), ('POST','/sanciones/disciplinarias'), ('PUT','/torneos/1/estado')]
for metodo, ruta in solo_admin:
    resp = planillero.open(ruta, method=metodo)
    verificar(f'Planillero bloqueado: {metodo} {ruta}', resp.status_code == 403, f'HTTP {resp.status_code}')

print('\n=== 2. VISTAS Y PROCEDIMIENTOS EN MYSQL ===')
conexion = None
cursor = None
try:
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)
    cursor.execute('SELECT DATABASE() AS bd, CURRENT_USER() AS usuario')
    identidad = cursor.fetchone()
    print('BD:', identidad['bd'], '| Usuario MySQL:', identidad['usuario'])
    cursor.execute("SELECT TABLE_NAME FROM information_schema.VIEWS WHERE TABLE_SCHEMA = DATABASE()")
    vistas = {fila['TABLE_NAME'] for fila in cursor.fetchall()}
    verificar('Las 17 vistas existen', VISTAS_REPORTE <= vistas, f'{len(VISTAS_REPORTE & vistas)}/{len(VISTAS_REPORTE)}')
    cursor.execute("SELECT ROUTINE_NAME FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_TYPE = 'PROCEDURE'")
    procedimientos = {fila['ROUTINE_NAME'] for fila in cursor.fetchall()}
    necesarios = {'sp_programar_partido','sp_agregar_a_planilla','sp_quitar_de_planilla','sp_registrar_gol','sp_eliminar_gol','sp_registrar_tarjeta','sp_eliminar_tarjeta','sp_marcar_partido_jugado','sp_sancion_disciplinaria','sp_cambiar_estado_torneo'}
    verificar('Procedimientos usados por Flask existen', necesarios <= procedimientos, f'{len(necesarios & procedimientos)}/{len(necesarios)}')
    cursor.execute("SELECT COUNT(*) AS n FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = DATABASE()")
    print('Triggers encontrados:', cursor.fetchone()['n'])
    cursor.execute('SHOW GRANTS')
    print('Permisos del usuario MySQL:')
    for fila in cursor.fetchall():
        print(' ', next(iter(fila.values())))
except Exception as exc:
    verificar('Conexión/metadatos MySQL', False, f'{type(exc).__name__}: {exc}')
finally:
    if cursor:
        cursor.close()
    if conexion:
        conexion.close()

print('\n=== 3. CONSULTAR TODAS LAS VISTAS (SOLO LECTURA) ===')
for nombre in sorted(VISTAS_REPORTE):
    respuesta = admin.get('/reportes/' + nombre)
    datos = respuesta.get_json(silent=True)
    verificar(nombre, respuesta.status_code == 200 and isinstance(datos, list), f'HTTP {respuesta.status_code}' + (f', {len(datos)} filas' if isinstance(datos,list) else ''))

print('\n=== RESULTADO ===')
print(f'{aciertos} comprobaciones correctas; {len(fallos)} fallidas.')
if fallos:
    print('Pendientes:', ', '.join(fallos))
    raise SystemExit(1)
print('Auditoría de lectura y permisos de rutas superada. Faltan pruebas de escritura y autenticación real.')
