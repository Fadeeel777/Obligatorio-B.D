# Torneo Interfacultades de Fútbol 5

Obligatorio de Base de Datos 1 (UCU, segundo semestre 2026).
Sistema para gestionar el torneo de fútbol 5 entre facultades: equipos, planteles, partidos, planillas, goles, tarjetas, sanciones y reportes.

- **Base de datos:** MySQL 8, con reglas de negocio en CHECK, triggers y procedimientos almacenados.
- **Backend:** Python + Flask (API REST), sin ORM.
- **Frontend:** no tiene. La aplicación se usa a través de la API, por ejemplo con curl o Postman.

## Estructura

```
base de datos/        Scripts SQL, se corren en orden (01 a 08)
tests/                09 - Casos que deben fallar (demostración de validaciones)
Backend/              app.py (API Flask), database.py (conexión), requirements.txt, Dockerfile
docker/               Configuración de MySQL para Docker
docker-compose.yml    Base de datos + aplicación
auditar_backend.py    Auditoría de solo lectura del backend
```

## Opción 1: con Docker (recomendada)

Solo hace falta tener [Docker Desktop](https://www.docker.com/products/docker-desktop/) abierto. Desde la raíz del proyecto:

```bash
docker compose up --build
```

Esto levanta dos servicios:

- **db:** MySQL 8.4. La primera vez que arranca ejecuta los scripts de `base de datos/` (01 a 08), así que la base queda con los datos de prueba y los usuarios por rol. Desde la máquina se accede por el puerto **3307** (usuario `root`, contraseña `root_docker`).
- **app:** la API, en **http://127.0.0.1:5001**. Arranca cuando la base terminó de cargarse.

Comandos útiles:

```bash
docker compose down        # apagar (los datos se conservan)
docker compose down -v     # apagar y borrar la base; al volver a levantar se recarga desde cero
```

Para correr los casos que deben fallar contra la base de Docker:

```bash
docker compose exec -T db sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --force' < "tests/09 - Casos que deben fallar.sql"
```

Las contraseñas de `docker-compose.yml` son solo para uso local. `MYSQL_ROOT_PASSWORD` y `FLASK_SECRET_KEY` se pueden cambiar con un archivo `.env` en la raíz del proyecto.

## Opción 2: sin Docker

### Requisitos

- MySQL Server 8.0 o superior
- Python 3.10 o superior (las versiones de `requirements.txt` no instalan en 3.9)

### 1. Crear la base de datos

Desde la raíz del proyecto, correr los scripts **en este orden** (no hay 03):

```bash
mysql -u root -p < "base de datos/01 - Tablas y checks.sql"
mysql -u root -p < "base de datos/02 - Datos maestros.sql"
mysql -u root -p < "base de datos/04 - Vistas.sql"
mysql -u root -p < "base de datos/05 - Triggers.sql"
mysql -u root -p < "base de datos/06 - Procedimientos.sql"
mysql -u root -p < "base de datos/07 - Datos de prueba.sql"
mysql -u root -p < "base de datos/08 - Usuarios.sql"
```

| Script | Contenido |
|---|---|
| 01 | Crea la base `torneo_futbol5` (la borra si ya existe), tablas, claves y CHECK |
| 02 | Turnos, facultades, complejos, canchas y usuarios de la aplicación |
| 04 | Vistas de los reportes |
| 05 | Triggers y función de suspensión |
| 06 | Procedimientos que usa la aplicación |
| 07 | Datos de prueba: tres ediciones del torneo |
| 08 | Usuarios de MySQL con permisos por rol |

Como el 01 borra la base, correr todo de nuevo deja el sistema en su estado inicial. También se puede hacer desde MySQL Workbench, abriendo y ejecutando cada archivo en el mismo orden.

Opcional, los casos que deben fallar:

```bash
mysql -u root -p --force < "tests/09 - Casos que deben fallar.sql"
```

Cada sentencia intenta algo prohibido (poner a un suspendido en la planilla, usar una cancha ocupada, corregir un partido después de las 48 horas, etc.) y tiene que dar error. `--force` hace que siga después de cada error. El script no deja cambios en la base.

### 2. Configurar el backend

```bash
cd Backend
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env             # Windows: copy .env.example .env
```

Completar `Backend/.env`:

- `DB_PASSWORD`: la contraseña de root de MySQL.
- `FLASK_SECRET_KEY`: una clave propia, por ejemplo generada con:
  ```bash
  python3 -c "import secrets; print(secrets.token_hex(32))"
  ```
- `DB_LOGIN_*`, `DB_ADMIN_*` y `DB_PLANILLERO_*` ya coinciden con `08 - Usuarios.sql`. Si se cambian las contraseñas en ese script, hay que cambiarlas también acá.

El `.env` no se sube al repositorio. Para comprobar la conexión:

```bash
python ProbarConexion.py
```

### 3. Levantar la aplicación

```bash
cd Backend
source .venv/bin/activate
python app.py
```

La API queda en **http://127.0.0.1:5000**. En macOS, si el puerto 5000 está ocupado por AirPlay, se puede usar otro: `flask --app app run --port 5001`.

## Usuarios de prueba

| Correo | Contraseña | Rol |
|---|---|---|
| admin@ucu.edu.uy | Admin2026! | administrador |
| planillero@ucu.edu.uy | Planillero2026! | planillero |

En la base las contraseñas se guardan como hash bcrypt. Para cambiarlas: `python Backend/ConfigurarPasswords.py`.

## Probar la API

Ejemplo con curl (con Docker el puerto es 5001; sin Docker, 5000). El login guarda la cookie de sesión en `cookies.txt` para las siguientes llamadas:

```bash
curl -c cookies.txt -H "Content-Type: application/json" \
     -d '{"correo": "admin@ucu.edu.uy", "password": "Admin2026!"}' \
     http://127.0.0.1:5001/login

curl -b cookies.txt http://127.0.0.1:5001/reportes
curl -b cookies.txt http://127.0.0.1:5001/reportes/v_tabla_posiciones
```

## Datos de prueba

- **Copa 2026 S1:** 4 equipos, finalizada.
- **Copa 2026 S2:** 6 equipos, en curso. Tiene 3 fechas jugadas (con un partido cancelado) y la fecha 5 programada. En la fecha 4, el partido 16 ya pasó pero sigue sin cargar, para probar la planilla; el 17 está postergado y el 18 programado. Tres jugadores están suspendidos en la fecha 4: por 3 amarillas, por roja y por sanción disciplinaria.
- **Copa 2027 S1:** en inscripción, con un equipo de 2 jugadores para probar el alta de planteles.

## Auditoría del backend

Desde la raíz, con el entorno virtual activado (sin Docker):

```bash
python auditar_backend.py
```

Revisa rutas, control de acceso por rol, vistas y procedimientos. No modifica datos.
