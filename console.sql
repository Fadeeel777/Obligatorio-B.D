CREATE DATABASE IF NOT EXISTS torneo_futbol5
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE torneo_futbol5;

-- ============ USUARIOS DE LA APP ============
CREATE TABLE login (
                       correo      VARCHAR(100) PRIMARY KEY,
                       contrasena  VARCHAR(255) NOT NULL,              -- hash, no texto plano
                       rol         ENUM('administrador','planillero') NOT NULL,
                       CHECK (correo LIKE '%_@_%._%')
);

-- ============ MAESTROS ============
CREATE TABLE facultad (
                          id_facultad INT AUTO_INCREMENT PRIMARY KEY,
                          nombre      VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE jugador (
                         ci               VARCHAR(8)   PRIMARY KEY,
                         nombre           VARCHAR(50)  NOT NULL,
                         apellido         VARCHAR(50)  NOT NULL,
                         email            VARCHAR(100) NOT NULL UNIQUE,
                         fecha_nacimiento DATE         NOT NULL,
                         id_facultad      INT          NOT NULL,
                         tipo             ENUM('grado','posgrado','docente','funcionario') NOT NULL,
                         FOREIGN KEY (id_facultad) REFERENCES facultad(id_facultad),
                         CHECK (ci REGEXP '^[0-9]{7,8}$'),
                         CHECK (email LIKE '%_@_%._%')
);

CREATE TABLE complejo (
                          id_complejo  INT AUTO_INCREMENT PRIMARY KEY,
                          nombre       VARCHAR(100) NOT NULL UNIQUE,
                          direccion    VARCHAR(150) NOT NULL,
                          departamento VARCHAR(50)  NOT NULL
);

CREATE TABLE cancha (
                        nombre_cancha VARCHAR(50) NOT NULL,
                        id_complejo   INT         NOT NULL,
                        superficie    ENUM('sintetico','parquet') NOT NULL,
                        techada       BOOLEAN     NOT NULL DEFAULT FALSE,
                        PRIMARY KEY (nombre_cancha, id_complejo),
                        FOREIGN KEY (id_complejo) REFERENCES complejo(id_complejo)
);

CREATE TABLE turno (
                       id_turno    INT AUTO_INCREMENT PRIMARY KEY,
                       hora_inicio TIME NOT NULL,
                       hora_fin    TIME NOT NULL,
                       UNIQUE (hora_inicio),
                       CHECK (hora_inicio < hora_fin),
                       CHECK (hora_inicio >= '18:00:00' AND hora_fin <= '23:00:00')
);

-- ============ TORNEO ============
CREATE TABLE torneo (
                        id_torneo    INT AUTO_INCREMENT PRIMARY KEY,
                        nombre       VARCHAR(100) NOT NULL,
                        anio         INT          NOT NULL,
                        semestre     TINYINT      NOT NULL,
                        fecha_inicio DATE         NOT NULL,
                        fecha_fin    DATE         NOT NULL,
                        estado       ENUM('inscripcion','en_curso','finalizado')
                                                  NOT NULL DEFAULT 'inscripcion',
                        UNIQUE (anio, semestre),
                        CHECK (semestre IN (1,2)),
                        CHECK (fecha_inicio <= fecha_fin)
);

CREATE TABLE fecha_torneo (
                              id_torneo    INT NOT NULL,
                              numero_fecha INT NOT NULL,
                              fecha_desde  DATE NOT NULL,
                              fecha_hasta  DATE NOT NULL,
                              PRIMARY KEY (id_torneo, numero_fecha),
                              FOREIGN KEY (id_torneo) REFERENCES torneo(id_torneo),
                              CHECK (numero_fecha >= 1),
                              CHECK (fecha_desde <= fecha_hasta)
);

-- ============ EQUIPOS Y PLANTELES ============
CREATE TABLE equipo (
                        id_equipo   INT AUTO_INCREMENT PRIMARY KEY,
                        nombre      VARCHAR(100) NOT NULL,
                        id_torneo   INT NOT NULL,
                        id_facultad INT NOT NULL,
                        ci_capitan  VARCHAR(8) NULL,   -- nullable: se asigna después de armar el plantel
                        FOREIGN KEY (id_torneo)   REFERENCES torneo(id_torneo),
                        FOREIGN KEY (id_facultad) REFERENCES facultad(id_facultad),
                        FOREIGN KEY (ci_capitan)  REFERENCES jugador(ci),
                        UNIQUE (id_torneo, nombre),
                        UNIQUE (id_equipo, id_torneo)  -- permite FK compuesta desde el plantel
);

CREATE TABLE equipo_jugador_torneo (
                                       id_equipo       INT        NOT NULL,
                                       ci_jugador      VARCHAR(8) NOT NULL,
                                       id_torneo       INT        NOT NULL,
                                       numero_camiseta TINYINT    NOT NULL,
                                       PRIMARY KEY (id_equipo, ci_jugador, id_torneo),
                                       FOREIGN KEY (id_equipo, id_torneo) REFERENCES equipo(id_equipo, id_torneo),
                                       FOREIGN KEY (ci_jugador) REFERENCES jugador(ci),
                                       UNIQUE (ci_jugador, id_torneo),      -- un solo equipo por edición
                                       UNIQUE (id_equipo, ci_jugador),      -- referenciable desde la planilla
                                       UNIQUE (id_equipo, numero_camiseta),
                                       CHECK (numero_camiseta BETWEEN 1 AND 99)
);

-- ============ PARTIDOS ============
CREATE TABLE partido (
                         id_partido          INT AUTO_INCREMENT PRIMARY KEY,
                         id_torneo           INT         NOT NULL,
                         numero_fecha        INT         NOT NULL,
                         id_equipo_local     INT         NOT NULL,
                         id_equipo_visitante INT         NOT NULL,
                         dia                 DATE        NOT NULL,
                         id_turno            INT         NOT NULL,
                         nombre_cancha       VARCHAR(50) NOT NULL,
                         id_complejo         INT         NOT NULL,
                         estado              ENUM('programado','jugado','postergado','cancelado')
                                                         NOT NULL DEFAULT 'programado',
                         fecha_hora_jugado   DATETIME NULL,   -- para la regla de las 48 h
                         FOREIGN KEY (id_torneo, numero_fecha) REFERENCES fecha_torneo(id_torneo, numero_fecha),
                         FOREIGN KEY (id_equipo_local,     id_torneo) REFERENCES equipo(id_equipo, id_torneo),
                         FOREIGN KEY (id_equipo_visitante, id_torneo) REFERENCES equipo(id_equipo, id_torneo),
                         FOREIGN KEY (id_turno) REFERENCES turno(id_turno),
                         FOREIGN KEY (nombre_cancha, id_complejo) REFERENCES cancha(nombre_cancha, id_complejo),
                         UNIQUE (id_complejo, nombre_cancha, dia, id_turno),   -- cancha ocupada
                         CHECK (id_equipo_local <> id_equipo_visitante),
                         CHECK ((estado = 'jugado' AND fecha_hora_jugado IS NOT NULL)
                             OR (estado <> 'jugado' AND fecha_hora_jugado IS NULL))
);

-- ============ PLANILLA, GOLES Y TARJETAS ============
CREATE TABLE planilla_partido (
                                  id_partido INT        NOT NULL,
                                  ci_jugador VARCHAR(8) NOT NULL,
                                  id_equipo  INT        NOT NULL,
                                  PRIMARY KEY (id_partido, ci_jugador),
                                  FOREIGN KEY (id_partido) REFERENCES partido(id_partido),
                                  FOREIGN KEY (id_equipo, ci_jugador)
                                      REFERENCES equipo_jugador_torneo(id_equipo, ci_jugador)  -- debe estar en el plantel
);

CREATE TABLE gol (
                     id_gol     INT AUTO_INCREMENT PRIMARY KEY,
                     id_partido INT        NOT NULL,
                     ci_jugador VARCHAR(8) NOT NULL,
                     minuto     TINYINT    NOT NULL,
                     autogol    BOOLEAN    NOT NULL DEFAULT FALSE,
                     FOREIGN KEY (id_partido, ci_jugador)
                         REFERENCES planilla_partido(id_partido, ci_jugador),     -- debe figurar en planilla
                     CHECK (minuto BETWEEN 0 AND 60)
);

CREATE TABLE tarjeta (
                         id_tarjeta INT AUTO_INCREMENT PRIMARY KEY,
                         id_partido INT        NOT NULL,
                         ci_jugador VARCHAR(8) NOT NULL,
                         minuto     TINYINT    NOT NULL,
                         color      ENUM('amarilla','roja') NOT NULL,
                         FOREIGN KEY (id_partido, ci_jugador)
                             REFERENCES planilla_partido(id_partido, ci_jugador),
                         CHECK (minuto BETWEEN 0 AND 60)
);

-- ============ SANCIONES ============
CREATE TABLE sancion_jugador (
                                 id_sancion          INT AUTO_INCREMENT PRIMARY KEY,
                                 ci_jugador          VARCHAR(8) NOT NULL,
                                 id_torneo           INT        NOT NULL,
                                 motivo              ENUM('roja','acumulacion_amarillas','disciplinaria') NOT NULL,
                                 numero_fecha_inicio INT        NOT NULL,
                                 cantidad_fechas     INT        NOT NULL,
                                 id_tarjeta_origen   INT NULL,   -- evita duplicar la sanción automática
                                 FOREIGN KEY (ci_jugador) REFERENCES jugador(ci),
                                 FOREIGN KEY (id_torneo)  REFERENCES torneo(id_torneo),
                                 FOREIGN KEY (id_tarjeta_origen) REFERENCES tarjeta(id_tarjeta),
                                 UNIQUE (id_tarjeta_origen),
                                 CHECK (numero_fecha_inicio >= 1),
                                 CHECK (cantidad_fechas >= 1)
);

INSERT INTO turno (hora_inicio, hora_fin) VALUES
                                              ('18:00','19:00'),('19:00','20:00'),('20:00','21:00'),
                                              ('21:00','22:00'),('22:00','23:00');

USE torneo_futbol5;

-- Los 5 turnos (18:00 a 23:00) ya se insertan en 01_schema.sql

-- ============ FACULTADES ============
INSERT INTO facultad (nombre) VALUES
                                  ('Ciencias Humanas'),
                                  ('Ciencias Empresariales'),
                                  ('Derecho'),
                                  ('Ingeniería y Tecnologías'),
                                  ('Psicología'),
                                  ('Ciencias de la Salud'),
                                  ('Artes y Diseño');

-- ============ COMPLEJOS ============
INSERT INTO complejo (nombre, direccion, departamento) VALUES
                                                           ('Complejo Campus UCU',    'Av. 8 de Octubre 2738',   'Montevideo'),
                                                           ('Fútbol 5 Pocitos',       'Bulevar Artigas 1450',    'Montevideo'),
                                                           ('Complejo Carrasco Indoor','Av. Italia 5620',        'Montevideo'),
                                                           ('Arena Ciudad de la Costa','Av. Giannattasio km 20', 'Canelones');

-- ============ CANCHAS ============
-- (el id_complejo coincide con el orden de los INSERT anteriores: 1 a 4)
INSERT INTO cancha (nombre_cancha, id_complejo, superficie, techada) VALUES
                                                                         ('Cancha 1', 1, 'sintetico', FALSE),
                                                                         ('Cancha 2', 1, 'sintetico', FALSE),
                                                                         ('Cancha 1', 2, 'sintetico', TRUE),
                                                                         ('Cancha 2', 2, 'parquet',   TRUE),
                                                                         ('Cancha A', 3, 'parquet',   TRUE),
                                                                         ('Cancha B', 3, 'parquet',   TRUE),
                                                                         ('Cancha 1', 4, 'sintetico', FALSE),
                                                                         ('Cancha 2', 4, 'sintetico', FALSE);

-- ============ USUARIOS DE LA APP ============
-- Contraseñas (hash bcrypt, costo 12):
--   admin@ucu.edu.uy       -> Admin2026!
--   planillero@ucu.edu.uy  -> Planillero2026!

INSERT INTO login (correo, contrasena, rol) VALUES
                                                ('admin@ucu.edu.uy',
                                                 '$2b$12$8mCcrrFQrzBBfLK/moXBWe.y6IC7PMNwLNJR9HbE8MMGMGbxeSO6q',
                                                 'administrador'),
                                                ('planillero@ucu.edu.uy',
                                                 '$2b$12$LyIiOaJo1hQm47PVmRQ9/OeKiNlndcWp67ITQ/Fw44iiw3VmFqMey',
                                                 'planillero');
-- ============================================================
-- 03_datos_prueba.sql
-- Datos de prueba: 1 torneo en curso, 6 equipos, 3 fechas jugadas,
-- 2 fechas programadas (con un partido postergado y uno cancelado).
-- Ejecutar DESPUES de 01_schema.sql y 02_datos_maestros.sql.
-- ============================================================
USE torneo_futbol5;

-- Canchas: se toman las 8 canchas de 02_datos_maestros.sql sin depender
-- de los nombres que se hayan elegido (2 por complejo, ordenadas por nombre).

SET @c1 = (SELECT nombre_cancha FROM cancha WHERE id_complejo = 1 ORDER BY nombre_cancha LIMIT 1 OFFSET 0);
SET @c2 = (SELECT nombre_cancha FROM cancha WHERE id_complejo = 1 ORDER BY nombre_cancha LIMIT 1 OFFSET 1);
SET @c3 = (SELECT nombre_cancha FROM cancha WHERE id_complejo = 2 ORDER BY nombre_cancha LIMIT 1 OFFSET 0);
SET @c4 = (SELECT nombre_cancha FROM cancha WHERE id_complejo = 2 ORDER BY nombre_cancha LIMIT 1 OFFSET 1);
SET @c5 = (SELECT nombre_cancha FROM cancha WHERE id_complejo = 3 ORDER BY nombre_cancha LIMIT 1 OFFSET 0);
SET @c6 = (SELECT nombre_cancha FROM cancha WHERE id_complejo = 3 ORDER BY nombre_cancha LIMIT 1 OFFSET 1);
SET @c7 = (SELECT nombre_cancha FROM cancha WHERE id_complejo = 4 ORDER BY nombre_cancha LIMIT 1 OFFSET 0);
SET @c8 = (SELECT nombre_cancha FROM cancha WHERE id_complejo = 4 ORDER BY nombre_cancha LIMIT 1 OFFSET 1);

-- ============ TORNEO Y FECHAS ============
INSERT INTO torneo (id_torneo, nombre, anio, semestre, fecha_inicio, fecha_fin, estado) VALUES
    (1, 'Torneo Interfacultades de Fútbol 5 - 2026/2', 2026, 2, '2026-10-05', '2026-11-13', 'en_curso');

INSERT INTO fecha_torneo (id_torneo, numero_fecha, fecha_desde, fecha_hasta) VALUES
                                                                                 (1, 1, '2026-10-05', '2026-10-09'),
                                                                                 (1, 2, '2026-10-12', '2026-10-16'),
                                                                                 (1, 3, '2026-10-19', '2026-10-23'),
                                                                                 (1, 4, '2026-11-02', '2026-11-06'),
                                                                                 (1, 5, '2026-11-09', '2026-11-13');

-- ============ JUGADORES ============
-- 42 jugadores en planteles (7 por equipo) + 4 de Artes y Diseño sin equipo
INSERT INTO jugador (ci, nombre, apellido, email, fecha_nacimiento, id_facultad, tipo) VALUES
                                                                                           ('4100007', 'Mateo', 'Fernández', 'mateo.fernandez0@correo.ucu.edu.uy', '2002-01-01', 1, 'grado'),
                                                                                           ('4117318', 'Santiago', 'Díaz', 'santiago.diaz1@correo.ucu.edu.uy', '2003-02-04', 1, 'grado'),
                                                                                           ('4134629', 'Joaquín', 'Techera', 'joaquin.techera2@correo.ucu.edu.uy', '2004-03-07', 1, 'grado'),
                                                                                           ('4151940', 'Facundo', 'Pereira', 'facundo.pereira3@correo.ucu.edu.uy', '2005-04-10', 1, 'grado'),
                                                                                           ('4169251', 'Nicolás', 'Rojas', 'nicolas.rojas4@correo.ucu.edu.uy', '1997-05-13', 1, 'posgrado'),
                                                                                           ('4186562', 'Agustín', 'Cardozo', 'agustin.cardozo5@correo.ucu.edu.uy', '1979-06-16', 1, 'docente'),
                                                                                           ('4203873', 'Lucas', 'Larrosa', 'lucas.larrosa6@correo.ucu.edu.uy', '1986-07-19', 1, 'funcionario'),
                                                                                           ('4221184', 'Martín', 'Ramos', 'martin.ramos7@correo.ucu.edu.uy', '2005-08-22', 2, 'grado'),
                                                                                           ('4238495', 'Bruno', 'Casal', 'bruno.casal8@correo.ucu.edu.uy', '2002-09-25', 2, 'grado'),
                                                                                           ('4255806', 'Franco', 'Pérez', 'franco.perez9@correo.ucu.edu.uy', '2003-10-01', 2, 'grado'),
                                                                                           ('4273117', 'Diego', 'Martínez', 'diego.martinez10@correo.ucu.edu.uy', '2004-11-04', 2, 'grado'),
                                                                                           ('4290428', 'Gonzalo', 'Álvarez', 'gonzalo.alvarez11@correo.ucu.edu.uy', '2005-12-07', 2, 'grado'),
                                                                                           ('4307739', 'Valentina', 'Núñez', 'valentina.nunez12@correo.ucu.edu.uy', '1997-01-10', 2, 'posgrado'),
                                                                                           ('4325050', 'Camila', 'Correa', 'camila.correa13@correo.ucu.edu.uy', '1979-02-13', 2, 'docente'),
                                                                                           ('4342361', 'Sofía', 'Vázquez', 'sofia.vazquez14@correo.ucu.edu.uy', '2004-03-16', 3, 'grado'),
                                                                                           ('4359672', 'Lucía', 'Bentancor', 'lucia.bentancor15@correo.ucu.edu.uy', '2005-04-19', 3, 'grado'),
                                                                                           ('4376983', 'Martina', 'Alonso', 'martina.alonso16@correo.ucu.edu.uy', '2002-05-22', 3, 'grado'),
                                                                                           ('4394294', 'Julieta', 'Moreira', 'julieta.moreira17@correo.ucu.edu.uy', '1998-06-25', 3, 'posgrado'),
                                                                                           ('4411605', 'Florencia', 'Mora', 'florencia.mora18@correo.ucu.edu.uy', '1999-07-01', 3, 'posgrado'),
                                                                                           ('4428916', 'Agustina', 'Rodríguez', 'agustina.rodriguez19@correo.ucu.edu.uy', '2005-08-04', 3, 'grado'),
                                                                                           ('4446227', 'Emiliano', 'Silva', 'emiliano.silva20@correo.ucu.edu.uy', '1984-09-07', 3, 'funcionario'),
                                                                                           ('4463538', 'Rodrigo', 'Rivero', 'rodrigo.rivero21@correo.ucu.edu.uy', '2003-10-10', 4, 'grado'),
                                                                                           ('4480849', 'Tomás', 'Méndez', 'tomas.mendez22@correo.ucu.edu.uy', '2004-11-13', 4, 'grado'),
                                                                                           ('4498160', 'Ignacio', 'Castro', 'ignacio.castro23@correo.ucu.edu.uy', '2005-12-16', 4, 'grado'),
                                                                                           ('4515471', 'Federico', 'Giménez', 'federico.gimenez24@correo.ucu.edu.uy', '2002-01-19', 4, 'grado'),
                                                                                           ('4532782', 'Maximiliano', 'Píriz', 'maximiliano.piriz25@correo.ucu.edu.uy', '1998-02-22', 4, 'posgrado'),
                                                                                           ('4550093', 'Sebastián', 'Techera', 'sebastian.techera26@correo.ucu.edu.uy', '1980-03-25', 4, 'docente'),
                                                                                           ('4567404', 'Andrés', 'Delgado', 'andres.delgado27@correo.ucu.edu.uy', '2005-04-01', 4, 'grado'),
                                                                                           ('4584715', 'Paula', 'Zeballos', 'paula.zeballos28@correo.ucu.edu.uy', '2002-05-04', 5, 'grado'),
                                                                                           ('4602026', 'Carolina', 'López', 'carolina.lopez29@correo.ucu.edu.uy', '2003-06-07', 5, 'grado'),
                                                                                           ('4619337', 'Natalia', 'Sosa', 'natalia.sosa30@correo.ucu.edu.uy', '2004-07-10', 5, 'grado'),
                                                                                           ('4636648', 'Victoria', 'Cabrera', 'victoria.cabrera31@correo.ucu.edu.uy', '2005-08-13', 5, 'grado'),
                                                                                           ('4653959', 'Renata', 'Suárez', 'renata.suarez32@correo.ucu.edu.uy', '2002-09-16', 5, 'grado'),
                                                                                           ('4671270', 'Micaela', 'Benítez', 'micaela.benitez33@correo.ucu.edu.uy', '2003-10-19', 5, 'grado'),
                                                                                           ('4688581', 'Brenda', 'Rey', 'brenda.rey34@correo.ucu.edu.uy', '1986-11-22', 5, 'funcionario'),
                                                                                           ('4705892', 'Rocío', 'Viera', 'rocio.viera35@correo.ucu.edu.uy', '2005-12-25', 6, 'grado'),
                                                                                           ('4723203', 'Felipe', 'Ibarra', 'felipe.ibarra36@correo.ucu.edu.uy', '2002-01-01', 6, 'grado'),
                                                                                           ('4740514', 'Gabriel', 'Ledesma', 'gabriel.ledesma37@correo.ucu.edu.uy', '2003-02-04', 6, 'grado'),
                                                                                           ('4757825', 'Daniel', 'González', 'daniel.gonzalez38@correo.ucu.edu.uy', '1999-03-07', 6, 'posgrado'),
                                                                                           ('4775136', 'Pablo', 'García', 'pablo.garcia39@correo.ucu.edu.uy', '2005-04-10', 6, 'grado'),
                                                                                           ('4792447', 'Ana', 'Romero', 'ana.romero40@correo.ucu.edu.uy', '1978-05-13', 6, 'docente'),
                                                                                           ('4809758', 'Laura', 'Acosta', 'laura.acosta41@correo.ucu.edu.uy', '1985-06-16', 6, 'funcionario'),
                                                                                           ('4827069', 'Marina', 'Ferreira', 'marina.ferreira42@correo.ucu.edu.uy', '2004-07-19', 7, 'grado'),
                                                                                           ('4844380', 'Lorena', 'Olivera', 'lorena.olivera43@correo.ucu.edu.uy', '2000-08-22', 7, 'posgrado'),
                                                                                           ('4861691', 'Ramiro', 'Machado', 'ramiro.machado44@correo.ucu.edu.uy', '1978-09-25', 7, 'docente'),
                                                                                           ('4879002', 'Esteban', 'Barrios', 'esteban.barrios45@correo.ucu.edu.uy', '1985-10-01', 7, 'funcionario');

-- ============ EQUIPOS (capitan = primer jugador de cada plantel) ============
INSERT INTO equipo (id_equipo, nombre, id_torneo, id_facultad, ci_capitan) VALUES
                                                                               (1, 'Humanas FC', 1, 1, '4100007'),
                                                                               (2, 'Empresariales United', 1, 2, '4221184'),
                                                                               (3, 'Derecho Atlético', 1, 3, '4342361'),
                                                                               (4, 'Ingeniería Racing', 1, 4, '4463538'),
                                                                               (5, 'Psico Club', 1, 5, '4584715'),
                                                                               (6, 'Salud Sport', 1, 6, '4705892');

-- ============ PLANTELES ============
INSERT INTO equipo_jugador_torneo (id_equipo, ci_jugador, id_torneo, numero_camiseta) VALUES
                                                                                          (1, '4100007', 1, 1),
                                                                                          (1, '4117318', 1, 7),
                                                                                          (1, '4134629', 1, 9),
                                                                                          (1, '4151940', 1, 10),
                                                                                          (1, '4169251', 1, 11),
                                                                                          (1, '4186562', 1, 14),
                                                                                          (1, '4203873', 1, 20),
                                                                                          (2, '4221184', 1, 1),
                                                                                          (2, '4238495', 1, 7),
                                                                                          (2, '4255806', 1, 9),
                                                                                          (2, '4273117', 1, 10),
                                                                                          (2, '4290428', 1, 11),
                                                                                          (2, '4307739', 1, 14),
                                                                                          (2, '4325050', 1, 20),
                                                                                          (3, '4342361', 1, 1),
                                                                                          (3, '4359672', 1, 7),
                                                                                          (3, '4376983', 1, 9),
                                                                                          (3, '4394294', 1, 10),
                                                                                          (3, '4411605', 1, 11),
                                                                                          (3, '4428916', 1, 14),
                                                                                          (3, '4446227', 1, 20),
                                                                                          (4, '4463538', 1, 1),
                                                                                          (4, '4480849', 1, 7),
                                                                                          (4, '4498160', 1, 9),
                                                                                          (4, '4515471', 1, 10),
                                                                                          (4, '4532782', 1, 11),
                                                                                          (4, '4550093', 1, 14),
                                                                                          (4, '4567404', 1, 20),
                                                                                          (5, '4584715', 1, 1),
                                                                                          (5, '4602026', 1, 7),
                                                                                          (5, '4619337', 1, 9),
                                                                                          (5, '4636648', 1, 10),
                                                                                          (5, '4653959', 1, 11),
                                                                                          (5, '4671270', 1, 14),
                                                                                          (5, '4688581', 1, 20),
                                                                                          (6, '4705892', 1, 1),
                                                                                          (6, '4723203', 1, 7),
                                                                                          (6, '4740514', 1, 9),
                                                                                          (6, '4757825', 1, 10),
                                                                                          (6, '4775136', 1, 11),
                                                                                          (6, '4792447', 1, 14),
                                                                                          (6, '4809758', 1, 20);

-- ============ PARTIDOS ============
-- Fechas 1 a 3: jugados (todos anteriores al 30/10/2026). Fecha 4 y 5: futuros.
INSERT INTO partido (id_partido, id_torneo, numero_fecha, id_equipo_local, id_equipo_visitante, dia, id_turno, nombre_cancha, id_complejo, estado, fecha_hora_jugado) VALUES
                                                                                                                                                                          (1, 1, 1, 1, 6, '2026-10-05', 1, @c1, 1, 'jugado', '2026-10-05 19:10:00'),
                                                                                                                                                                          (2, 1, 1, 2, 5, '2026-10-05', 2, @c1, 1, 'jugado', '2026-10-05 20:10:00'),
                                                                                                                                                                          (3, 1, 1, 3, 4, '2026-10-06', 3, @c3, 2, 'jugado', '2026-10-06 21:10:00'),
                                                                                                                                                                          (4, 1, 2, 1, 5, '2026-10-12', 2, @c1, 1, 'jugado', '2026-10-12 20:10:00'),
                                                                                                                                                                          (5, 1, 2, 6, 4, '2026-10-13', 3, @c5, 3, 'jugado', '2026-10-13 21:10:00'),
                                                                                                                                                                          (6, 1, 2, 2, 3, '2026-10-14', 3, @c3, 2, 'jugado', '2026-10-14 21:10:00'),
                                                                                                                                                                          (7, 1, 3, 1, 4, '2026-10-19', 2, @c1, 1, 'jugado', '2026-10-19 20:10:00'),
                                                                                                                                                                          (8, 1, 3, 5, 3, '2026-10-20', 4, @c7, 4, 'jugado', '2026-10-20 22:10:00'),
                                                                                                                                                                          (9, 1, 3, 6, 2, '2026-10-21', 3, @c5, 3, 'jugado', '2026-10-21 21:10:00'),
                                                                                                                                                                          (10, 1, 4, 1, 3, '2026-11-02', 2, @c1, 1, 'programado', NULL),
                                                                                                                                                                          (11, 1, 4, 4, 2, '2026-11-03', 3, @c3, 2, 'postergado', NULL),
                                                                                                                                                                          (12, 1, 4, 5, 6, '2026-11-04', 4, @c7, 4, 'programado', NULL),
                                                                                                                                                                          (13, 1, 5, 1, 2, '2026-11-09', 2, @c1, 1, 'programado', NULL),
                                                                                                                                                                          (14, 1, 5, 3, 6, '2026-11-10', 3, @c5, 3, 'programado', NULL),
                                                                                                                                                                          (15, 1, 5, 4, 5, '2026-11-11', 5, @c8, 4, 'cancelado', NULL);

-- ============ PLANILLAS (solo partidos jugados) ============
INSERT INTO planilla_partido (id_partido, ci_jugador, id_equipo) VALUES
                                                                     (1, '4100007', 1),
                                                                     (1, '4117318', 1),
                                                                     (1, '4134629', 1),
                                                                     (1, '4151940', 1),
                                                                     (1, '4169251', 1),
                                                                     (1, '4186562', 1),
                                                                     (1, '4705892', 6),
                                                                     (1, '4723203', 6),
                                                                     (1, '4740514', 6),
                                                                     (1, '4757825', 6),
                                                                     (1, '4775136', 6),
                                                                     (2, '4221184', 2),
                                                                     (2, '4238495', 2),
                                                                     (2, '4255806', 2),
                                                                     (2, '4273117', 2),
                                                                     (2, '4290428', 2),
                                                                     (2, '4584715', 5),
                                                                     (2, '4602026', 5),
                                                                     (2, '4619337', 5),
                                                                     (2, '4636648', 5),
                                                                     (2, '4653959', 5),
                                                                     (3, '4342361', 3),
                                                                     (3, '4359672', 3),
                                                                     (3, '4376983', 3),
                                                                     (3, '4394294', 3),
                                                                     (3, '4411605', 3),
                                                                     (3, '4463538', 4),
                                                                     (3, '4480849', 4),
                                                                     (3, '4498160', 4),
                                                                     (3, '4515471', 4),
                                                                     (3, '4532782', 4),
                                                                     (3, '4550093', 4),
                                                                     (4, '4100007', 1),
                                                                     (4, '4117318', 1),
                                                                     (4, '4134629', 1),
                                                                     (4, '4151940', 1),
                                                                     (4, '4169251', 1),
                                                                     (4, '4584715', 5),
                                                                     (4, '4602026', 5),
                                                                     (4, '4619337', 5),
                                                                     (4, '4636648', 5),
                                                                     (4, '4671270', 5),
                                                                     (5, '4705892', 6),
                                                                     (5, '4723203', 6),
                                                                     (5, '4740514', 6),
                                                                     (5, '4757825', 6),
                                                                     (5, '4775136', 6),
                                                                     (5, '4463538', 4),
                                                                     (5, '4480849', 4),
                                                                     (5, '4498160', 4),
                                                                     (5, '4515471', 4),
                                                                     (5, '4532782', 4),
                                                                     (6, '4221184', 2),
                                                                     (6, '4238495', 2),
                                                                     (6, '4255806', 2),
                                                                     (6, '4273117', 2),
                                                                     (6, '4290428', 2),
                                                                     (6, '4342361', 3),
                                                                     (6, '4359672', 3),
                                                                     (6, '4376983', 3),
                                                                     (6, '4394294', 3),
                                                                     (6, '4411605', 3),
                                                                     (7, '4100007', 1),
                                                                     (7, '4117318', 1),
                                                                     (7, '4134629', 1),
                                                                     (7, '4151940', 1),
                                                                     (7, '4169251', 1),
                                                                     (7, '4463538', 4),
                                                                     (7, '4480849', 4),
                                                                     (7, '4498160', 4),
                                                                     (7, '4532782', 4),
                                                                     (7, '4550093', 4),
                                                                     (8, '4584715', 5),
                                                                     (8, '4602026', 5),
                                                                     (8, '4619337', 5),
                                                                     (8, '4636648', 5),
                                                                     (8, '4653959', 5),
                                                                     (8, '4342361', 3),
                                                                     (8, '4359672', 3),
                                                                     (8, '4376983', 3),
                                                                     (8, '4394294', 3),
                                                                     (8, '4411605', 3),
                                                                     (8, '4428916', 3),
                                                                     (9, '4705892', 6),
                                                                     (9, '4723203', 6),
                                                                     (9, '4740514', 6),
                                                                     (9, '4757825', 6),
                                                                     (9, '4775136', 6),
                                                                     (9, '4221184', 2),
                                                                     (9, '4238495', 2),
                                                                     (9, '4255806', 2),
                                                                     (9, '4273117', 2),
                                                                     (9, '4307739', 2);

-- ============ GOLES (autogol = 1: suma al rival del jugador) ============
INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES
                                                              (1, '4100007', 10, 0),
                                                              (1, '4117318', 25, 0),
                                                              (1, '4775136', 33, 0),
                                                              (1, '4100007', 48, 0),
                                                              (2, '4238495', 8, 0),
                                                              (2, '4584715', 30, 0),
                                                              (2, '4636648', 41, 0),
                                                              (2, '4238495', 52, 0),
                                                              (3, '4342361', 44, 1),
                                                              (4, '4134629', 37, 0),
                                                              (5, '4480849', 22, 0),
                                                              (5, '4775136', 15, 0),
                                                              (5, '4757825', 40, 0),
                                                              (5, '4532782', 57, 0),
                                                              (6, '4238495', 5, 0),
                                                              (6, '4238495', 19, 0),
                                                              (6, '4359672', 28, 0),
                                                              (6, '4273117', 36, 0),
                                                              (6, '4221184', 51, 0),
                                                              (7, '4480849', 9, 0),
                                                              (7, '4100007', 12, 0),
                                                              (7, '4532782', 31, 0),
                                                              (7, '4117318', 40, 0),
                                                              (7, '4169251', 54, 1),
                                                              (8, '4584715', 26, 0),
                                                              (8, '4359672', 49, 0),
                                                              (9, '4238495', 14, 0),
                                                              (9, '4307739', 46, 0);

-- ============ TARJETAS ============
INSERT INTO tarjeta (id_tarjeta, id_partido, ci_jugador, minuto, color) VALUES
                                                                            (1, 1, '4740514', 20, 'amarilla'),
                                                                            (2, 1, '4151940', 35, 'amarilla'),
                                                                            (3, 2, '4584715', 12, 'amarilla'),
                                                                            (4, 2, '4238495', 40, 'amarilla'),
                                                                            (5, 2, '4653959', 55, 'roja'),
                                                                            (6, 3, '4376983', 30, 'amarilla'),
                                                                            (7, 3, '4480849', 51, 'amarilla'),
                                                                            (8, 4, '4619337', 22, 'amarilla'),
                                                                            (9, 4, '4151940', 45, 'amarilla'),
                                                                            (10, 5, '4740514', 50, 'amarilla'),
                                                                            (11, 5, '4515471', 58, 'roja'),
                                                                            (12, 6, '4376983', 33, 'amarilla'),
                                                                            (13, 6, '4290428', 47, 'amarilla'),
                                                                            (14, 7, '4151940', 15, 'amarilla'),
                                                                            (15, 7, '4498160', 59, 'roja'),
                                                                            (16, 8, '4602026', 20, 'amarilla'),
                                                                            (17, 8, '4376983', 38, 'amarilla'),
                                                                            (18, 9, '4705892', 52, 'roja');

-- ============ SANCIONES ============
-- roja: 1 fecha, desde la fecha siguiente | acumulacion_amarillas: 3ra amarilla del torneo
-- disciplinaria: aplicada por la organizacion, sin tarjeta de origen
INSERT INTO sancion_jugador (id_sancion, ci_jugador, id_torneo, motivo, numero_fecha_inicio, cantidad_fechas, id_tarjeta_origen) VALUES
                                                                                                                                     (1, '4653959', 1, 'roja', 2, 1, 5),
                                                                                                                                     (2, '4515471', 1, 'roja', 3, 1, 11),
                                                                                                                                     (3, '4498160', 1, 'roja', 4, 1, 15),
                                                                                                                                     (4, '4705892', 1, 'roja', 4, 1, 18),
                                                                                                                                     (5, '4151940', 1, 'acumulacion_amarillas', 4, 1, 14),
                                                                                                                                     (6, '4376983', 1, 'acumulacion_amarillas', 4, 1, 17),
                                                                                                                                     (7, '4290428', 1, 'disciplinaria', 3, 2, NULL),
                                                                                                                                     (8, '4723203', 1, 'disciplinaria', 4, 2, NULL);

SELECT id_facultad, nombre FROM facultad ORDER BY id_facultad